<#
Twisted Computing Tech Utility - GitHub bootstrapper
Usage:
irm https://raw.githubusercontent.com/jasonpsu97/TCTech-Utility/main/launch.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Owner      = 'jasonpsu97'
$Repository = 'TCTech-Utility'
$Branch     = 'main'
$InstallDir = Join-Path $env:LOCALAPPDATA 'TwistedComputing\TCTech-Utility'
$TempDir    = Join-Path $env:TEMP ('TCTech-Utility-' + [guid]::NewGuid().ToString('N'))
$ZipPath    = Join-Path $TempDir 'TCTech-Utility.zip'
$ExtractDir = Join-Path $TempDir 'Extracted'
$ZipUrl     = "https://github.com/$Owner/$Repository/archive/refs/heads/$Branch.zip"

function Show-TCError {
    param([string]$Message)

    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        [System.Windows.MessageBox]::Show(
            $Message,
            'Twisted Computing Tech Utility',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    catch {
        Write-Host $Message -ForegroundColor Red
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw 'Windows PowerShell 5.1 or newer is required.'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    New-Item -ItemType Directory -Path $TempDir, $ExtractDir -Force | Out-Null

    Write-Host 'Downloading Twisted Computing Tech Utility...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractDir -Force

    $SourceRoot = Get-ChildItem -LiteralPath $ExtractDir -Directory | Select-Object -First 1
    if (-not $SourceRoot) {
        throw 'The GitHub download did not contain a project folder.'
    }

    $MainScript = Join-Path $SourceRoot.FullName 'winutil.ps1'
    $AppLauncher = Join-Path $SourceRoot.FullName 'Launch-TCTech-Utility.ps1'

    if (-not (Test-Path -LiteralPath $MainScript)) {
        throw 'winutil.ps1 is missing from the root of the GitHub repository.'
    }

    if (-not (Test-Path -LiteralPath $AppLauncher)) {
        throw 'Launch-TCTech-Utility.ps1 is missing from the root of the GitHub repository.'
    }

    $StagingDir = "$InstallDir.new"
    Remove-Item -LiteralPath $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceRoot.FullName '*') -Destination $StagingDir -Recurse -Force

    Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $StagingDir -Destination $InstallDir -Force

    $InstalledLauncher = Join-Path $InstallDir 'Launch-TCTech-Utility.ps1'

    Write-Host 'Starting Twisted Computing Tech Utility...' -ForegroundColor Green
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoLogo'
        '-NoProfile'
        '-STA'
        '-ExecutionPolicy', 'Bypass'
        '-WindowStyle', 'Hidden'
        '-File', ('"{0}"' -f $InstalledLauncher)
    ) -WorkingDirectory $InstallDir -WindowStyle Hidden
}
catch {
    $Message = "Unable to download or launch the utility.`n`n$($_.Exception.Message)"
    Show-TCError -Message $Message
    throw
}
finally {
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
