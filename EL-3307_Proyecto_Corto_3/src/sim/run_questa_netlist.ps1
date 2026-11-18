[CmdletBinding()]
param(
    [string]$GowinBin = 'C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/bin',
    [string]$QuestaBin = 'C:/altera_pro/26.1.1/questa_fse/win64',
    [string]$BuildDirectory = '',
    [switch]$SkipBuild,
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$project3 = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$reused = Join-Path $project3 'src/design/reused'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function ConvertTo-NativeArgument {
    param([string]$Value)
    $quoted = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $quoted = [regex]::Replace($quoted, '(\\+)$', '$1$1')
    return '"' + $quoted + '"'
}

function Get-ShortDirectory {
    param([string]$Path)
    $fileSystem = New-Object -ComObject Scripting.FileSystemObject
    try { return $fileSystem.GetFolder($Path).ShortPath }
    finally { [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($fileSystem) }
}

function Get-RelativeToolPath {
    param([string]$BaseDirectory, [string]$Target)
    $baseUri = New-Object System.Uri(($BaseDirectory.TrimEnd('\', '/') + '/'))
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri([System.Uri]$Target).ToString())
}

function Invoke-NetlistTool {
    param([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory,
          [string]$Log, [hashtable]$Environment = @{})
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.Arguments = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($key in $Environment.Keys) { $info.EnvironmentVariables[$key] = $Environment[$key] }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            # Solo se termina el proceso iniciado por esta invocacion.
            & (Join-Path $env:SystemRoot 'System32/taskkill.exe') /PID $process.Id /T /F 2>&1 | Out-Null
            $process.WaitForExit()
            throw "Timeout: $Executable"
        }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [System.IO.File]::WriteAllText($Log, $output, $utf8)
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output }
    }
    finally { $process.Dispose() }
}

function Require-Success {
    param($Result, [string]$Description)
    if ($Result.ExitCode -ne 0 -or $Result.Output -match '(?im)^\s*(?:#\s*)?\*\*\s*(?:Error|Fatal)\b|Error loading design|ERROR\s*\(') {
        throw "$Description failed; inspect its log."
    }
}

function Simulate-Netlist {
    param([string]$Phase, [string]$Netlist, [string]$PrimitiveLibrary, [string]$Sdf = '')
    $phaseDirectory = Join-Path $runDirectory $Phase
    $runtime = Join-Path $phaseDirectory 'runtime/build'
    [void](New-Item -ItemType Directory -Path $runtime -Force)
    $working = Get-ShortDirectory $runtime
    foreach ($operation in @(
        @{Tool='vlib'; Args=@('../../library'); Log='vlib.log'},
        @{Tool='vmap'; Args=@('-c'); Log='vmap_create.log'},
        @{Tool='vmap'; Args=@('-ini','modelsim.ini','work','../../library'); Log='vmap_work.log'}
    )) {
        $result = Invoke-NetlistTool (Join-Path $QuestaBin ($operation.Tool + '.exe')) $operation.Args $working (Join-Path $phaseDirectory $operation.Log)
        Require-Success $result $operation.Tool
    }
    $sources = @($PrimitiveLibrary, $Netlist, (Join-Path $PSScriptRoot 'tb_vending_netlist.sv'))
    $relativeSources = @($sources | ForEach-Object { Get-RelativeToolPath $runtime $_ })
    $compile = Invoke-NetlistTool (Join-Path $QuestaBin 'vlog.exe') (@('-sv','-ini','modelsim.ini','-work','work') + $relativeSources) $working (Join-Path $phaseDirectory 'compile.log')
    Require-Success $compile "$Phase compilation"
    if ($compile.Output -notmatch 'Errors:\s*0\b') { throw "$Phase compilation lacks a zero-error result." }

    $doFile = Join-Path $phaseDirectory 'run.do'
    [System.IO.File]::WriteAllLines($doFile, @(
        'onerror {quit -force -code 1}',
        'onbreak {quit -force -code 1}',
        'run -all',
        'quit -force -code 1'
    ), $utf8)
    $arguments = @('-c','-onfinish','exit','-voptargs=+acc','-ini','modelsim.ini',
        '-l','../../transcript.log','-wlf','../../simulation.wlf','-do','../../run.do')
    if ($Sdf) {
        $relativeSdf = Get-RelativeToolPath $runtime $Sdf
        $arguments += @('-sdfmax',('/tb_vending_netlist/uut=' + $relativeSdf),
                        '-sdfreport=../../sdf_report.txt','+sdf_verbose')
    }
    $arguments += 'work.tb_vending_netlist'
    $simulation = Invoke-NetlistTool (Join-Path $QuestaBin 'vsim.exe') $arguments $working (Join-Path $phaseDirectory 'simulation.log')
    Require-Success $simulation "$Phase simulation"
    $transcript = Join-Path $phaseDirectory 'transcript.log'
    if (-not (Test-Path -LiteralPath $transcript)) { throw "$Phase transcript missing." }
    $combined = $simulation.Output + [System.IO.File]::ReadAllText($transcript)
    if ($combined -match '(?im)^\s*(?:#\s*)?FAIL:|\b[1-9][0-9]*\s+errors\b') { throw "$Phase testbench reported a failure." }
    $summary = [regex]::Match($combined, 'RESULT:\s*([0-9]+)\s+tests,\s*0\s+errors')
    if (-not $summary.Success) { throw "$Phase lacks a passing zero-error summary." }
    $paths = 0
    $timingChecks = 0
    $interconnects = 0
    if ($Sdf) {
        $annotationReport = Join-Path $phaseDirectory 'sdf_report.txt'
        if (-not (Test-Path -LiteralPath $annotationReport)) { throw 'Questa did not generate an SDF annotation report.' }
        # sdfreport enumera objetos SIN anotar. La evidencia de anotacion esta
        # en el resumen +sdf_verbose, no en la existencia de ese archivo.
        $paths = [regex]::Match($combined, 'Module path delays\s*=\s*(\d+)')
        $timingChecks = [regex]::Match($combined, 'Timing checks\s*=\s*(\d+)')
        $interconnects = [regex]::Match($combined, 'Scalar MIPDs\s*=\s*(\d+)')
        $iopaths = [regex]::Match($combined, 'IOPATH\s*=\s*(\d+)')
        $connections = [regex]::Match($combined, 'INTERCONNECT\s*=\s*(\d+)')
        if ($combined -notmatch 'SDF Backannotation Successfully Completed' -or
            -not $paths.Success -or -not $timingChecks.Success -or -not $interconnects.Success -or
            -not $iopaths.Success -or -not $connections.Success) {
            throw 'Questa did not confirm actual SDF delay and timing-check annotation.'
        }
        $paths = [int]$paths.Groups[1].Value
        $timingChecks = [int]$timingChecks.Groups[1].Value
        $interconnects = [int]$interconnects.Groups[1].Value
        if ($paths -le 0 -or $timingChecks -le 0 -or $interconnects -le 0 -or
            $paths -ne [int]$iopaths.Groups[1].Value -or
            $interconnects -ne [int]$connections.Groups[1].Value) {
            throw 'The SDF construct counts do not match the annotated paths and interconnects.'
        }
    }
    return [pscustomobject]@{ Phase=$Phase; Result='PASS'; Checks=[int]$summary.Groups[1].Value;
        SdfAnnotated=[bool]$Sdf; SdfPaths=$paths; SdfTimingChecks=$timingChecks;
        SdfInterconnects=$interconnects; Netlist=$Netlist; PrimitiveLibrary=$PrimitiveLibrary; Transcript=$transcript }
}

try {
    if (-not $BuildDirectory) {
        if ($SkipBuild) { throw 'SkipBuild requires BuildDirectory.' }
        $name = 'netlist_{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'), ([guid]::NewGuid().ToString('N').Substring(0,8))
        $BuildDirectory = Join-Path (Join-Path $project3 'work') $name
    }
    $runDirectory = [System.IO.Path]::GetFullPath($BuildDirectory)
    $workRoot = [System.IO.Path]::GetFullPath((Join-Path $project3 'work')).TrimEnd('\') + '\'
    if (-not $runDirectory.StartsWith($workRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'BuildDirectory must be inside Proyecto Corto 3/work.'
    }
    [void](New-Item -ItemType Directory -Path $runDirectory -Force)
    $gowinOutput = Join-Path $runDirectory 'gowin'
    [void](New-Item -ItemType Directory -Path $gowinOutput -Force)
    $gowinProject = Join-Path $gowinOutput 'vending_verify_top'
    $gowinIde = Split-Path -Parent $GowinBin
    $functionalPrimitives = Join-Path $gowinIde 'simlib/gw1n/prim_sim.v'
    $timingPrimitives = Join-Path $gowinIde 'simlib/gw1n/prim_tsim.v'
    foreach ($required in @((Join-Path $GowinBin 'gw_sh.exe'), $functionalPrimitives, $timingPrimitives)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Missing tool/library: $required" }
    }
    Write-Host "Netlist artifacts: $runDirectory"

    $designInputs = @(Get-ChildItem -LiteralPath (Join-Path $project3 'src/design') -Filter '*.sv' -File | Sort-Object Name | ForEach-Object { $_.FullName })
    $designInputs += @(Get-ChildItem -LiteralPath $reused -Filter '*.sv' -File | Sort-Object Name | ForEach-Object { $_.FullName })
    $designInputs += @((Join-Path $project3 'src/constr/vending_top.cst'),
                      (Join-Path $project3 'src/constr/vending_top.sdc'),
                      (Join-Path $reused 'bcdtable.txt'),
                      (Join-Path $project3 'src/build/verify_netlist_gowin.tcl'))
    $hashes = @($designInputs | ForEach-Object { [pscustomobject]@{Path=$_; SHA256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash} })
    $inputMetadata = Join-Path $runDirectory 'design_inputs.json'
    if ($SkipBuild) {
        $originalInputs = @((Get-Content -LiteralPath $inputMetadata -Raw -Encoding utf8 | ConvertFrom-Json))
        if ($originalInputs.Count -ne $hashes.Count) { throw 'The design source list changed since this build.' }
        foreach ($source in $hashes) {
            $original = @($originalInputs | Where-Object { $_.Path -eq $source.Path })
            if ($original.Count -ne 1 -or $original[0].SHA256 -ne $source.SHA256) { throw "Source changed since build: $($source.Path)" }
        }
    } else {
        [System.IO.File]::WriteAllText($inputMetadata, ($hashes | ConvertTo-Json -Depth 3), $utf8)
        $working = Get-ShortDirectory $runDirectory
        $helper = Get-RelativeToolPath $runDirectory (Join-Path $project3 'src/build/verify_netlist_gowin.tcl')
        $build = Invoke-NetlistTool (Join-Path $GowinBin 'gw_sh.exe') @($helper) $working (Join-Path $runDirectory 'gowin.log') @{VENDING_NETLIST_OUTPUT=(Get-ShortDirectory $gowinOutput)}
        Require-Success $build 'Gowin verification build'
        if ($build.Output -notmatch 'GowinSynthesis finish' -or $build.Output -notmatch 'Placement and routing completed') {
            throw 'Gowin did not confirm synthesis and place/route completion.'
        }
    }

    $synthesisNetlist = Join-Path $gowinProject 'impl/gwsynthesis/vending_verify_top.vg'
    $routedNetlist = Join-Path $gowinProject 'impl/pnr/vending_verify_top.vo'
    $sdf = Join-Path $gowinProject 'impl/pnr/vending_verify_top.sdf'
    foreach ($artifact in @($synthesisNetlist,$routedNetlist,$sdf)) {
        if (-not (Test-Path -LiteralPath $artifact)) { throw "Missing build artifact: $artifact" }
    }
    $results = @()
    try {
        $results += Simulate-Netlist 'post_synthesis' $synthesisNetlist $functionalPrimitives
        Write-Host 'PASS: post-synthesis simulation'
    }
    catch {
        $status = 'FAIL'
        $reason = $_.Exception.Message
        $compileLog = Join-Path $runDirectory 'post_synthesis/compile.log'
        if ($reason -match '^post_synthesis compilation' -and
            [System.IO.File]::ReadAllText($synthesisNetlist) -match 'key_keyowner="GOWIN"' -and
            (Test-Path -LiteralPath $compileLog) -and
            [System.IO.File]::ReadAllText($compileLog) -match 'Pragma protect|STRING_LITERAL') {
            $status = 'UNAVAILABLE'
            $reason = 'Questa rejects the GOWIN protected .vg envelope; inspect post_synthesis/compile.log.'
        }
        $results += [pscustomobject]@{Phase='post_synthesis';Result=$status;Reason=$reason;SdfAnnotated=$false}
        Write-Host ($status + ': post-synthesis simulation: ' + $reason)
    }
    try {
        $results += Simulate-Netlist 'post_route_sdf' $routedNetlist $timingPrimitives $sdf
        Write-Host 'PASS: post-route simulation with SDF'
    }
    catch {
        $results += [pscustomobject]@{Phase='post_route_sdf';Result='FAIL';Reason=$_.Exception.Message;SdfAnnotated=$false}
        Write-Host ('FAIL: post-route simulation: ' + $_.Exception.Message)
    }
    $complete = @($results | Where-Object { $_.Result -ne 'PASS' }).Count -eq 0
    $metadata = [pscustomobject]@{
        Result=$(if(@($results | Where-Object { $_.Result -eq 'FAIL' }).Count){'FAIL'}elseif($complete){'PASS'}else{'PARTIAL'});
        Parameters=@{DEBOUNCE_N=4;REFUND_CYCLES=256;DISPLAY_DIV=3};
        ProductionRtlModified=$false;
        TestbenchSHA256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'tb_vending_netlist.sv') -Algorithm SHA256).Hash;
        Results=$results
    }
    [System.IO.File]::WriteAllText((Join-Path $runDirectory 'results.json'), ($metadata | ConvertTo-Json -Depth 6), $utf8)
    Write-Host ("RESULT: " + $metadata.Result)
    if (@($results | Where-Object { $_.Result -eq 'FAIL' }).Count) { exit 1 }
    if (-not $complete) { exit 2 }
    exit 0
}
catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
