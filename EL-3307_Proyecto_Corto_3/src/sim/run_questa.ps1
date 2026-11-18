[CmdletBinding()]
param(
    [string]$QuestaBin = '',
    [string[]]$Tests = @(),
    [switch]$CompileOnly,
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# All generated files, including the ROM's relative-path fixture, stay in work/.
$project3 = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$reused = Join-Path $project3 'src/design/reused'
$runName = 'questa_{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$runDirectory = Join-Path (Join-Path $project3 'work') $runName
$utf8 = New-Object System.Text.UTF8Encoding($false)

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    # Quote directly for CreateProcess; no command shell evaluates the arguments.
    $quoted = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $quoted = [regex]::Replace($quoted, '(\\+)$', '$1$1')
    return '"' + $quoted + '"'
}

function Invoke-QuestaTool {
    param(
        [string]$Tool,
        [string[]]$ToolArguments,
        [string]$LogName,
        [string]$WorkingDirectory = $toolWorkingDirectory
    )

    $logPath = Join-Path $runDirectory $LogName
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $script:executables[$Tool]
    $info.Arguments = ($ToolArguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    $timedOut = $false
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            # Terminate only the process tree created by this invocation.
            $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
            & $taskkill /PID $process.Id /T /F 2>&1 | Out-Null
            $process.WaitForExit()
        }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [System.IO.File]::WriteAllText($logPath, $output, $utf8)
        if ($timedOut) {
            throw "$Tool exceeded ${TimeoutSeconds}s. See $logPath"
        }
        if ($process.ExitCode -ne 0) {
            throw "$Tool returned exit code $($process.ExitCode). See $logPath"
        }
        if ($output -match '(?im)^\s*(?:#\s*)?\*\*\s*(?:Error|Fatal)\b|Error loading design|Unable to checkout|License checkout failed|Failed to obtain.*license') {
            throw "$Tool reported an error. See $logPath"
        }
        return $output
    }
    finally {
        $process.Dispose()
    }
}

try {
    $script:executables = @{}
    foreach ($tool in @('vlib', 'vmap', 'vlog', 'vsim')) {
        if ($QuestaBin) {
            $candidate = Join-Path $QuestaBin ($tool + '.exe')
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                throw "Questa executable missing: $candidate"
            }
            $script:executables[$tool] = (Get-Item -LiteralPath $candidate).FullName
        }
        else {
            $script:executables[$tool] = (Get-Command ($tool + '.exe') -CommandType Application -ErrorAction Stop).Source
        }
    }

    $sources = @(Get-ChildItem -LiteralPath (Join-Path $project3 'src/design') -Filter '*.sv' -File | Sort-Object Name | ForEach-Object { $_.FullName })
    # Each directory is read once; no modules from another project are added.
    $sources += @(Get-ChildItem -LiteralPath $reused -Filter '*.sv' -File | Sort-Object Name | ForEach-Object { $_.FullName })
    $project3Tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'tb_*.sv' -File |
        Where-Object BaseName -ne 'tb_vending_netlist' | Sort-Object Name)
    $sources += @($project3Tests | ForEach-Object { $_.FullName })
    $availableTests = @($project3Tests | ForEach-Object { $_.BaseName })
    $selectedTests = if ($Tests.Count) { $Tests } else { $availableTests }
    foreach ($test in $selectedTests) {
        if ($test -notin $availableTests) {
            throw "Unknown test '$test'. Available: $($availableTests -join ', ')"
        }
    }
    foreach ($source in $sources) {
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Source file missing: $source"
        }
    }
    $romSource = Join-Path $reused 'bcdtable.txt'
    if (-not (Test-Path -LiteralPath $romSource -PathType Leaf)) {
        throw "BCD ROM missing: $romSource"
    }

    [void](New-Item -ItemType Directory -Path $runDirectory)
    $runtimeDirectory = Join-Path $runDirectory 'runtime/build'
    $romDirectory = Join-Path $runDirectory 'runtime/design'
    [void](New-Item -ItemType Directory -Path $runtimeDirectory)
    [void](New-Item -ItemType Directory -Path $romDirectory)
    $toolWorkingDirectory = $runtimeDirectory
    if ($toolWorkingDirectory -match '[^\x00-\x7F]') {
        # Questa's SQLite library also needs an ASCII spelling of the current
        # directory. The existing 8.3 alias refers to the same workspace folder.
        $fileSystem = New-Object -ComObject Scripting.FileSystemObject
        $toolWorkingDirectory = $fileSystem.GetFolder($runtimeDirectory).ShortPath
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($fileSystem)
        if ($toolWorkingDirectory -match '[^\x00-\x7F]') {
            throw 'Questa cannot use this Unicode workspace: an ASCII 8.3 path alias is unavailable.'
        }
    }
    # All PC3 ROM instances have nine address bits. Preserve the complete local
    # source table and stage its first 512 entries, just as the Gowin flow does.
    $romEntries = [System.IO.File]::ReadAllLines($romSource)
    if ($romEntries.Count -ne 1024) { throw 'Expected 1024 entries in the local BCD table.' }
    $romImage = Join-Path $romDirectory 'bcdtable.txt'
    [System.IO.File]::WriteAllLines($romImage, [string[]]$romEntries[0..511], $utf8)
    [System.IO.File]::WriteAllLines((Join-Path $runDirectory 'sources.txt'), [string[]]$sources, $utf8)
    $metadata = [pscustomobject]@{
        WorkingDirectory = $runtimeDirectory
        QuestaWorkingDirectory = $toolWorkingDirectory
        Executables = $script:executables
        Tests = @($selectedTests)
        Sources = @($sources | ForEach-Object {
            [pscustomobject]@{ Path = $_; SHA256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }
        })
        Rom = [pscustomobject]@{ Path = $romSource; SHA256 = (Get-FileHash -LiteralPath $romSource -Algorithm SHA256).Hash;
            Image = $romImage; InitializedEntries = 512; ImageSHA256 = (Get-FileHash -LiteralPath $romImage -Algorithm SHA256).Hash }
    }
    [System.IO.File]::WriteAllText((Join-Path $runDirectory 'metadata.json'), ($metadata | ConvertTo-Json -Depth 5), $utf8)
    Write-Host "Questa artifacts: $runDirectory"

    # Questa's legacy argument parser mishandles some Unicode absolute paths.
    # Keep its working directory in Win32's Unicode API and pass relative paths.
    $baseUri = New-Object System.Uri(($runtimeDirectory.TrimEnd('\') + '\'))
    $sourceArguments = @($sources | ForEach-Object {
        [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri([System.Uri]$_).ToString())
    })
    [void](Invoke-QuestaTool 'vlib' @('../../library') 'vlib.log')
    [void](Invoke-QuestaTool 'vmap' @('-c') 'vmap_create.log')
    [void](Invoke-QuestaTool 'vmap' @('-ini', 'modelsim.ini', 'work', '../../library') 'vmap_work.log')
    $compileArguments = @('-sv', '-ini', 'modelsim.ini', '-work', 'work') + $sourceArguments
    $compileOutput = Invoke-QuestaTool 'vlog' $compileArguments 'compile.log'
    if ($compileOutput -notmatch 'Errors:\s*0\b') {
        throw "Compilation did not report zero errors. See $(Join-Path $runDirectory 'compile.log')"
    }
    Write-Host "Compilation: PASS ($($sources.Count) sources)"
    if ($CompileOnly) {
        exit 0
    }

    $doFile = Join-Path $runDirectory 'run_test.do'
    $doCommands = @('onerror {quit -force -code 1}', 'onbreak {quit -force -code 1}', 'run -all', 'quit -force -code 1')
    [System.IO.File]::WriteAllLines($doFile, $doCommands, $utf8)
    $results = @()
    foreach ($test in $selectedTests) {
        $transcript = Join-Path $runDirectory "$test.transcript.log"
        $arguments = @('-c', '-onfinish', 'exit', '-voptargs=+acc', '-ini', 'modelsim.ini', '-l', "../../$test.transcript.log", '-wlf', "../../$test.wlf", '-do', '../../run_test.do', "work.$test")
        $output = Invoke-QuestaTool 'vsim' $arguments "$test.process.log"
        if (-not (Test-Path -LiteralPath $transcript -PathType Leaf)) {
            throw "Missing transcript for $test"
        }
        $transcriptText = [System.IO.File]::ReadAllText($transcript)
        $combined = $output + "`n" + $transcriptText
        if ($combined -match '(?im)^\s*(?:#\s*)?(?:\*\*\s*(?:Error|Fatal)\b|FAIL:|Resultado general:\s*FAIL)|\b[1-9][0-9]*\s+errors\b|\bErrores:\s*[1-9]') {
            throw "$test reported a failure. See $transcript"
        }
        $zeroErrors = $combined -match '\bRESULT:\s*[0-9]+\s+tests,\s*0\s+errors\b'
        $spanishPass = ($combined -match '\bErrores:\s*0\b') -and ($combined -match 'Resultado general:\s*PASS')
        if (-not ($zeroErrors -or $spanishPass)) {
            throw "$test has no passing zero-error summary. See $transcript"
        }
        $checkCount = [regex]::Match($combined, '(?i)(?:\bRESULT:\s*|\bpruebas:\s*)([0-9]+)')
        if (-not $checkCount.Success) {
            throw "$test has no explicit check count. See $transcript"
        }
        $checks = [int]$checkCount.Groups[1].Value
        $results += [pscustomobject]@{ Test = $test; Result = 'PASS'; Checks = $checks; Transcript = $transcript }
        Write-Host "PASS: $test ($checks checks)"
    }
    $totalChecks = ($results | Measure-Object -Property Checks -Sum).Sum
    $summary = [pscustomobject]@{ Result = 'PASS'; Tests = $results.Count; Checks = $totalChecks; Artifacts = $runDirectory; Results = $results }
    [System.IO.File]::WriteAllText((Join-Path $runDirectory 'results.json'), ($summary | ConvertTo-Json -Depth 4), $utf8)
    Write-Host "RESULT: $($results.Count) testbenches, $totalChecks checks, 0 errors"
    exit 0
}
catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
