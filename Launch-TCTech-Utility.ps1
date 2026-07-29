param([switch]$Elevated)

$ErrorActionPreference = 'Stop'
$basePath   = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $basePath 'winutil.ps1'
$logFile    = Join-Path $basePath 'TCTech-Launch-Error.log'

function Show-TCError([string]$Message) {
    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    [System.Windows.MessageBox]::Show(
        $Message,
        'Twisted Computing Tech Utility',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
}

try {
    if (-not (Test-Path -LiteralPath $mainScript)) {
        throw 'winutil.ps1 was not found beside the launcher. Extract the entire ZIP before launching.'
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $isAdmin) {
        $arg = "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Elevated"
        Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -Verb RunAs -WindowStyle Hidden -WorkingDirectory $basePath
        exit 0
    }

    Remove-Item -LiteralPath $logFile -Force -ErrorAction SilentlyContinue
    Set-Location -LiteralPath $basePath

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="True" Topmost="True"
        Width="470" Height="280" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="18" Background="#FF202428" BorderBrush="#FF3A8CC7" BorderThickness="2">
        <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="0" Opacity="0.65" Color="#FF000000"/></Border.Effect>
        <Grid Margin="28">
            <Grid.RowDefinitions>
                <RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Grid Grid.Row="0" HorizontalAlignment="Center" VerticalAlignment="Center">
                <Image x:Name="TCLogo" Width="120" Height="120" Stretch="Uniform"/>
            </Grid>
            <StackPanel Grid.Row="1" Margin="0,2,0,16">
                <TextBlock Text="TWISTED COMPUTING" Foreground="White" FontFamily="Segoe UI Semibold"
                           FontSize="21" FontWeight="SemiBold" HorizontalAlignment="Center"/>
                <TextBlock Text="T E C H   U T I L I T Y" Foreground="#FFB9C5CE" FontFamily="Segoe UI" FontSize="13"
                           FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,3,0,0"/>
            </StackPanel>
            <StackPanel Grid.Row="2">
                <ProgressBar IsIndeterminate="True" Height="5" BorderThickness="0"/>
                <TextBlock Text="Loading technician tools..." Foreground="#FFB9C5CE" FontFamily="Segoe UI"
                           FontSize="12" HorizontalAlignment="Center" Margin="0,10,0,0"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
'@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $splash = [Windows.Markup.XamlReader]::Load($reader)
    $logoControl = $splash.FindName('TCLogo')
    $logoPath = Join-Path $basePath 'assets\tctech-logo.png'
    if ($logoControl -and (Test-Path -LiteralPath $logoPath)) {
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = New-Object System.Uri($logoPath, [System.UriKind]::Absolute)
        $bitmap.EndInit()
        $bitmap.Freeze()
        $logoControl.Source = $bitmap
    }
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(3000)
    $timer.Add_Tick({
        $timer.Stop()
        $splash.Close()
    })
    $splash.Add_ContentRendered({ $timer.Start() })
    $null = $splash.ShowDialog()

    # Run the utility in this same elevated STA process. This avoids WinUtil's
    # internal Windows Terminal/admin relaunch path entirely.
    & $mainScript
}
catch {
    $details = $_ | Out-String
    try { $details | Set-Content -LiteralPath $logFile -Encoding UTF8 -Force } catch {}
    Show-TCError "Unable to launch the utility.`n`n$($_.Exception.Message)`n`nDetails were saved to:`n$logFile"
    exit 1
}
