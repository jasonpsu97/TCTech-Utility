function Show-WPFTCTechTextOutput {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    [xml]$outputXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$([System.Security.SecurityElement]::Escape($Title))"
        Width="900" Height="600" MinWidth="650" MinHeight="400"
        WindowStartupLocation="CenterOwner" Background="#202020">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBox Name="OutputText" Grid.Row="0" IsReadOnly="True" AcceptsReturn="True"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                 FontFamily="Consolas" FontSize="13" TextWrapping="NoWrap"
                 Background="#111111" Foreground="#F2F2F2" BorderBrush="#505050"
                 Padding="10"/>
        <Button Name="CloseButton" Grid.Row="1" Content="Close" Width="110" Height="34"
                HorizontalAlignment="Right" Margin="0,10,0,0"/>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $outputXaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $window.Owner = $sync.Form
    $window.FindName('OutputText').Text = $Text
    $window.FindName('CloseButton').Add_Click({ $window.Close() })
    $window.ShowDialog() | Out-Null
}

function ConvertTo-WPFTCTechIPv4Number {
    param([Parameter(Mandatory)][System.Net.IPAddress]$IPAddress)

    $bytes = $IPAddress.GetAddressBytes()
    if ($bytes.Count -ne 4) {
        throw 'Only IPv4 CIDR ranges are supported.'
    }

    return ([uint32]$bytes[0] -shl 24) -bor
           ([uint32]$bytes[1] -shl 16) -bor
           ([uint32]$bytes[2] -shl 8) -bor
           [uint32]$bytes[3]
}

function ConvertFrom-WPFTCTechIPv4Number {
    param([Parameter(Mandatory)][uint32]$Number)

    return [System.Net.IPAddress]::Parse(('{0}.{1}.{2}.{3}' -f
        (($Number -shr 24) -band 255),
        (($Number -shr 16) -band 255),
        (($Number -shr 8) -band 255),
        ($Number -band 255)))
}

function Get-WPFTCTechCIDRRange {
    param([Parameter(Mandatory)][string]$CIDR)

    if ($CIDR -notmatch '^\s*(?<address>(?:\d{1,3}\.){3}\d{1,3})\s*/\s*(?<prefix>\d{1,2})\s*$') {
        throw 'Enter an IPv4 address with CIDR notation, such as 192.168.1.0/24.'
    }

    $address = $null
    if (-not [System.Net.IPAddress]::TryParse($Matches.address, [ref]$address)) {
        throw 'The IPv4 address is not valid.'
    }

    $prefix = [int]$Matches.prefix
    if ($prefix -lt 16 -or $prefix -gt 32) {
        throw 'For safety, the scanner accepts prefixes from /16 through /32.'
    }

    $addressNumber = ConvertTo-WPFTCTechIPv4Number -IPAddress $address
    $mask = if ($prefix -eq 0) { [uint32]0 } else { [uint32]([uint64]0xFFFFFFFF -shl (32 - $prefix)) }
    $network = [uint32]($addressNumber -band $mask)
    $hostCount = [uint64]1 -shl (32 - $prefix)
    $broadcast = [uint32]([uint64]$network + $hostCount - 1)

    $first = $network
    $last = $broadcast
    if ($prefix -le 30) {
        $first = [uint32]($network + 1)
        $last = [uint32]($broadcast - 1)
    }

    [pscustomobject]@{
        Network = ConvertFrom-WPFTCTechIPv4Number -Number $network
        Broadcast = ConvertFrom-WPFTCTechIPv4Number -Number $broadcast
        First = $first
        Last = $last
        Count = [uint64]$last - [uint64]$first + 1
        Prefix = $prefix
    }
}

function Invoke-WPFTCTechARPScanner {
    [xml]$scannerXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Twisted Computing ARP / CIDR Scanner"
        Width="960" Height="650" MinWidth="760" MinHeight="500"
        WindowStartupLocation="CenterOwner" Background="#202020">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0">
            <TextBlock Text="ARP / CIDR Scanner" Foreground="White" FontSize="22" FontWeight="Bold"/>
            <TextBlock Text="Enter a range such as 192.168.1.0/24 or 172.24.0.1/26. Active hosts are pinged first, then resolved from the ARP table and DNS when available."
                       Foreground="#D0D0D0" TextWrapping="Wrap" Margin="0,5,0,10"/>
        </StackPanel>
        <Grid Grid.Row="1" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox Name="CIDRText" Grid.Column="0" Height="36" FontSize="15" Padding="8,5" Text="192.168.1.0/24"/>
            <Button Name="ScanButton" Grid.Column="1" Content="Scan" Width="110" Height="36" Margin="8,0,0,0"/>
            <Button Name="CloseButton" Grid.Column="2" Content="Close" Width="110" Height="36" Margin="8,0,0,0"/>
        </Grid>
        <DataGrid Name="ResultsGrid" Grid.Row="2" AutoGenerateColumns="False" IsReadOnly="True"
                  CanUserAddRows="False" HeadersVisibility="Column" GridLinesVisibility="Horizontal"
                  Background="#111111" Foreground="White" RowBackground="#171717" AlternatingRowBackground="#252525"
                  BorderBrush="#505050">
            <DataGrid.Columns>
                <DataGridTextColumn Header="IP Address" Binding="{Binding IPAddress}" Width="150"/>
                <DataGridTextColumn Header="MAC Address" Binding="{Binding MACAddress}" Width="175"/>
                <DataGridTextColumn Header="Hostname" Binding="{Binding Hostname}" Width="*"/>
                <DataGridTextColumn Header="Response" Binding="{Binding Response}" Width="110"/>
            </DataGrid.Columns>
        </DataGrid>
        <StackPanel Grid.Row="3" Margin="0,10,0,0">
            <ProgressBar Name="ScanProgress" Height="8" Minimum="0" Maximum="100" Value="0"/>
            <TextBlock Name="StatusText" Text="Ready." Foreground="#D0D0D0" Margin="0,6,0,0"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $scannerXaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $window.Owner = $sync.Form

    $cidrText = $window.FindName('CIDRText')
    $scanButton = $window.FindName('ScanButton')
    $closeButton = $window.FindName('CloseButton')
    $resultsGrid = $window.FindName('ResultsGrid')
    $progress = $window.FindName('ScanProgress')
    $status = $window.FindName('StatusText')

    $closeButton.Add_Click({ $window.Close() })
    $scanButton.Add_Click({
        try {
            $range = Get-WPFTCTechCIDRRange -CIDR $cidrText.Text
        } catch {
            [System.Windows.MessageBox]::Show($_.Exception.Message, 'Invalid subnet', 'OK', 'Warning') | Out-Null
            return
        }

        $scanButton.IsEnabled = $false
        $cidrText.IsEnabled = $false
        $results = New-Object System.Collections.ObjectModel.ObservableCollection[object]
        $resultsGrid.ItemsSource = $results
        $progress.Value = 0
        $status.Text = "Scanning $($range.Network)/$($range.Prefix) ($($range.Count) usable address(es))..."

        $sync.TCTechScannerWindow = $window
        $sync.TCTechScannerResults = $results
        $sync.TCTechScannerProgress = $progress
        $sync.TCTechScannerStatus = $status
        $sync.TCTechScannerButton = $scanButton
        $sync.TCTechScannerCIDR = $cidrText

        Invoke-WPFRunspace -ScriptBlock {
            param($ScanRange)

            $alive = New-Object System.Collections.Generic.List[object]
            $batchSize = 64
            $current = [uint64]$ScanRange.First
            $last = [uint64]$ScanRange.Last
            $processed = [uint64]0
            $total = [uint64]$ScanRange.Count

            while ($current -le $last) {
                $batch = New-Object System.Collections.Generic.List[object]
                for ($i = 0; $i -lt $batchSize -and $current -le $last; $i++, $current++) {
                    $ip = ConvertFrom-WPFTCTechIPv4Number -Number ([uint32]$current)
                    $ping = New-Object System.Net.NetworkInformation.Ping
                    $task = $ping.SendPingAsync($ip, 350)
                    $batch.Add([pscustomobject]@{ IP = $ip; Ping = $ping; Task = $task })
                }

                foreach ($entry in $batch) {
                    try {
                        $reply = $entry.Task.GetAwaiter().GetResult()
                        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                            $alive.Add([pscustomobject]@{ IP = $entry.IP; Time = $reply.RoundtripTime })
                        }
                    } catch {
                    } finally {
                        $entry.Ping.Dispose()
                        $processed++
                    }
                }

                $percent = [math]::Min(100, [math]::Round(($processed / [double]$total) * 100, 0))
                Invoke-WPFUIThread -ScriptBlock {
                    $sync.TCTechScannerProgress.Value = $percent
                    $sync.TCTechScannerStatus.Text = "Scanned $processed of $total address(es); $($alive.Count) active."
                }
            }

            try { arp.exe -a | Out-Null } catch {}
            $arpLines = @(arp.exe -a 2>$null)

            foreach ($hostEntry in $alive) {
                $ipText = $hostEntry.IP.IPAddressToString
                $escapedIP = [regex]::Escape($ipText)
                $arpLine = $arpLines | Where-Object { $_ -match "^\s*$escapedIP\s+([0-9a-fA-F-]{17})\s+" } | Select-Object -First 1
                $mac = if ($arpLine -and $arpLine -match "^\s*$escapedIP\s+([0-9a-fA-F-]{17})\s+") { $Matches[1].ToUpperInvariant() } else { '' }
                $hostname = ''
                try { $hostname = ([System.Net.Dns]::GetHostEntry($ipText)).HostName } catch {}

                $row = [pscustomobject]@{
                    IPAddress = $ipText
                    MACAddress = $mac
                    Hostname = $hostname
                    Response = "$($hostEntry.Time) ms"
                }

                Invoke-WPFUIThread -ScriptBlock { $sync.TCTechScannerResults.Add($row) }
            }

            Invoke-WPFUIThread -ScriptBlock {
                $sync.TCTechScannerProgress.Value = 100
                $sync.TCTechScannerStatus.Text = "Complete. Found $($alive.Count) active host(s)."
                $sync.TCTechScannerButton.IsEnabled = $true
                $sync.TCTechScannerCIDR.IsEnabled = $true
            }
        } -ArgumentList $range | Out-Null
    })

    $window.ShowDialog() | Out-Null
}

function Invoke-WPFTCTechIPConfig {
    $output = (& ipconfig.exe /all 2>&1 | Out-String)
    Show-WPFTCTechTextOutput -Title 'Full IP Configuration' -Text $output
}

function Invoke-WPFTCTechPingGateway {
    try {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop |
            Sort-Object RouteMetric, InterfaceMetric |
            Select-Object -First 1
        if (-not $route -or -not $route.NextHop -or $route.NextHop -eq '0.0.0.0') {
            throw 'No active IPv4 default gateway was found.'
        }
        $output = (& ping.exe -n 4 $route.NextHop 2>&1 | Out-String)
        Show-WPFTCTechTextOutput -Title "Ping Gateway - $($route.NextHop)" -Text $output
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Ping Default Gateway', 'OK', 'Warning') | Out-Null
    }
}

function Invoke-WPFTCTechClearARP {
    $output = (& arp.exe -d '*' 2>&1 | Out-String)
    if ([string]::IsNullOrWhiteSpace($output)) { $output = 'ARP cache cleared successfully.' }
    Show-WPFTCTechTextOutput -Title 'Clear ARP Cache' -Text $output
}

function Invoke-WPFTCTechFlushDNS {
    $output = (& ipconfig.exe /flushdns 2>&1 | Out-String)
    Show-WPFTCTechTextOutput -Title 'Flush DNS Cache' -Text $output
}

function Invoke-WPFTCTechRenewDHCP {
    $answer = [System.Windows.MessageBox]::Show(
        'This will temporarily interrupt network connectivity while Windows releases and renews DHCP leases. Continue?',
        'Release / Renew DHCP',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $release = (& ipconfig.exe /release 2>&1 | Out-String)
    $renew = (& ipconfig.exe /renew 2>&1 | Out-String)
    Show-WPFTCTechTextOutput -Title 'Release / Renew DHCP' -Text ($release + [Environment]::NewLine + $renew)
}

function Invoke-WPFTCTechRestartExplorer {
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Start-Process explorer.exe
        [System.Windows.MessageBox]::Show('Windows Explorer was restarted.', 'Restart Explorer', 'OK', 'Information') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Restart Explorer', 'OK', 'Error') | Out-Null
    }
}

function Invoke-WPFTCTechOpenAdapters {
    Start-Process control.exe -ArgumentList 'ncpa.cpl'
}
