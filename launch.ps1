# Twisted Computing Tech Utility - GitHub bootstrap launcher
# Usage: irm https://raw.githubusercontent.com/jasonpsu97/TCTech-Utility/main/launch.ps1 | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoOwner = 'jasonpsu97'
$repoName  = 'TCTech-Utility'
$branch    = 'main'
$appRoot   = Join-Path $env:LOCALAPPDATA 'TwistedComputing\TCTech-Utility'
$download  = Join-Path $env:TEMP 'TCTech-Utility.zip'
$extract   = Join-Path $env:TEMP ('TCTech-Utility-' + [guid]::NewGuid().ToString('N'))

function Show-TCLauncherError {
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
        Write-Error $Message
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw 'Windows PowerShell 5.1 or newer is required.'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zipUrl = "https://github.com/$repoOwner/$repoName/archive/refs/heads/$branch.zip"

    Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $extract -Force | Out-Null

    Invoke-WebRequest -Uri $zipUrl -OutFile $download -UseBasicParsing
    Expand-Archive -LiteralPath $download -DestinationPath $extract -Force

    $sourceRoot = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
    if (-not $sourceRoot) {
        throw 'The downloaded GitHub archive did not contain the application folder.'
    }

    $staging = "$appRoot.new"
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    Copy-Item -Path (Join-Path $sourceRoot.FullName '*') -Destination $staging -Recurse -Force

    if (-not (Test-Path -LiteralPath (Join-Path $staging 'Launch-TCTech-Utility.ps1'))) {
        throw 'Launch-TCTech-Utility.ps1 was not found in the downloaded repository.'
    }

    Remove-Item -LiteralPath $appRoot -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $staging -Destination $appRoot -Force

    $localLauncher = Join-Path $appRoot 'Launch-TCTech-Utility.ps1'
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$localLauncher`"" `
        -WindowStyle Hidden
}
catch {
    Show-TCLauncherError "Unable to download or launch the utility.`n`n$($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
}
