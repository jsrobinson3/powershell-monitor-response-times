<#
.SYNOPSIS
    MSP Network Diagnostics Tool - Tests common network scenarios and issues
.DESCRIPTION
    Comprehensive network testing script for on-site diagnostics including:
    - DHCP server detection and conflicts
    - Multicast storm detection
    - Network performance testing
    - DNS resolution testing
    - Port connectivity testing
    - Network discovery and scanning
.AUTHOR
    MSP Network Team
.VERSION
    1.1
#>

[CmdletBinding()]
param(
    [switch]$QuickScan,
    [switch]$DeepScan,
    [string]$LogPath = "C:\Temp\NetworkDiag_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    [string]$TargetSubnet = $null,
    [int]$ScanTimeout = 30
)

# Initialize logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level){"ERROR"{"Red"}"WARN"{"Yellow"}"SUCCESS"{"Green"}default{"White"}})
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

# Create log directory if it doesn't exist
$logDir = Split-Path $LogPath -Parent
if (!(Test-Path $logDir)) { 
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null 
}

Write-Log "Starting MSP Network Diagnostics Tool" "SUCCESS"
Write-Log "Log file: $LogPath"

# Get network adapter information
function Get-NetworkAdapterInfo {
    Write-Log "=== NETWORK ADAPTER INFORMATION ===" "SUCCESS"
    
    try {
        $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
        foreach ($adapter in $adapters) {
            Write-Log "Adapter: $($adapter.Name) - $($adapter.InterfaceDescription)"
            Write-Log "  Status: $($adapter.Status) | Speed: $($adapter.LinkSpeed) | MAC: $($adapter.MacAddress)"
            
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($ipConfig) {
                Write-Log "  IP: $($ipConfig.IPAddress)/$($ipConfig.PrefixLength)"
            }
            
            $gateway = Get-NetRoute -InterfaceIndex $adapter.InterfaceIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
            if ($gateway) {
                Write-Log "  Gateway: $($gateway.NextHop)"
            }
        }
    }
    catch {
        Write-Log "Error getting network adapter info: $($_.Exception.Message)" "ERROR"
    }
}

# DHCP Server Detection and Conflict Testing
function Test-DHCPServers {
    Write-Log "=== DHCP SERVER DETECTION ===" "SUCCESS"
    
    try {
        $dhcpServers = @()
        $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
        
        foreach ($adapter in $adapters) {
            Write-Log "Testing DHCP on interface: $($adapter.Name)"
            
            # Get current DHCP lease info
            $dhcpInfo = Get-NetIPConfiguration -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
            if ($dhcpInfo -and $dhcpInfo.NetProfile.IPv4Connectivity -eq "Internet") {
                if ($dhcpInfo.IPv4DefaultGateway) {
                    $dhcpServer = $dhcpInfo.IPv4DefaultGateway.NextHop
                    Write-Log "  DHCP Server detected: $dhcpServer"
                    $dhcpServers += $dhcpServer
                }
            }
            
            # Perform DHCP discovery using netsh
            try {
                $netshResult = netsh interface ip show config name="$($adapter.Name)" 2>$null
                $dhcpEnabled = $netshResult | Select-String "DHCP enabled.*Yes"
                if ($dhcpEnabled) {
                    $dhcpServerLine = $netshResult | Select-String "DHCP Server"
                    if ($dhcpServerLine) {
                        $server = ($dhcpServerLine -split ":")[1].Trim()
                        if ($server -and $server -ne "None" -and $dhcpServers -notcontains $server) {
                            Write-Log "  Additional DHCP Server found: $server" "WARN"
                            $dhcpServers += $server
                        }
                    }
                }
            }
            catch {
                Write-Log "  Could not query DHCP info for $($adapter.Name): $($_.Exception.Message)" "WARN"
            }
        }
        
        # Check for multiple DHCP servers (potential conflict)
        $uniqueServers = $dhcpServers | Sort-Object -Unique
        if ($uniqueServers.Count -gt 1) {
            Write-Log "POTENTIAL DHCP CONFLICT DETECTED! Multiple servers found:" "ERROR"
            foreach ($server in $uniqueServers) {
                Write-Log "  - $server" "ERROR"
            }
        }
        elseif ($uniqueServers.Count -eq 1) {
            Write-Log "Single DHCP server detected: $($uniqueServers[0])" "SUCCESS"
        }
        else {
            Write-Log "No DHCP servers detected or static IP configuration" "WARN"
        }
    }
    catch {
        Write-Log "Error testing DHCP servers: $($_.Exception.Message)" "ERROR"
    }
}

# Multicast Storm Detection
function Test-MulticastTraffic {
    Write-Log "=== MULTICAST STORM DETECTION ===" "SUCCESS"
    
    try {
        # Get network statistics before
        $initialStats = Get-NetAdapterStatistics
        Write-Log "Monitoring multicast traffic for 10 seconds..."
        
        Start-Sleep -Seconds 10
        
        # Get network statistics after
        $finalStats = Get-NetAdapterStatistics
        
        foreach ($adapter in ($initialStats | Where-Object {$_.Name -in (Get-NetAdapter | Where-Object Status -eq "Up").Name})) {
            $initial = $initialStats | Where-Object Name -eq $adapter.Name
            $final = $finalStats | Where-Object Name -eq $adapter.Name
            
            if ($initial -and $final) {
                $multicastDelta = $final.ReceivedMulticastPackets - $initial.ReceivedMulticastPackets
                $broadcastDelta = $final.ReceivedBroadcastPackets - $initial.ReceivedBroadcastPackets
                $totalPacketsDelta = $final.ReceivedPackets - $initial.ReceivedPackets
                
                Write-Log "Interface: $($adapter.Name)"
                Write-Log "  Multicast packets (10s): $multicastDelta"
                Write-Log "  Broadcast packets (10s): $broadcastDelta"
                Write-Log "  Total packets (10s): $totalPacketsDelta"
                
                # Define thresholds for storm detection
                $multicastThreshold = 1000  # packets per 10 seconds
                $broadcastThreshold = 500   # packets per 10 seconds
                
                if ($multicastDelta -gt $multicastThreshold) {
                    Write-Log "  MULTICAST STORM DETECTED! ($multicastDelta packets/10s)" "ERROR"
                }
                if ($broadcastDelta -gt $broadcastThreshold) {
                    Write-Log "  BROADCAST STORM DETECTED! ($broadcastDelta packets/10s)" "ERROR"
                }
                
                # Calculate percentage of multicast/broadcast traffic
                if ($totalPacketsDelta -gt 0) {
                    $multicastPercent = [math]::Round(($multicastDelta / $totalPacketsDelta) * 100, 2)
                    $broadcastPercent = [math]::Round(($broadcastDelta / $totalPacketsDelta) * 100, 2)
                    Write-Log "  Multicast %: $multicastPercent% | Broadcast %: $broadcastPercent%"
                    
                    if ($multicastPercent -gt 20 -or $broadcastPercent -gt 10) {
                        Write-Log "  HIGH MULTICAST/BROADCAST RATIO DETECTED!" "WARN"
                    }
                }
            }
        }
    }
    catch {
        Write-Log "Error monitoring multicast traffic: $($_.Exception.Message)" "ERROR"
    }
}

# DNS Resolution Testing
function Test-DNSResolution {
    Write-Log "=== DNS RESOLUTION TESTING ===" "SUCCESS"
    
    try {
        $testDomains = @(
            "google.com",
            "microsoft.com", 
            "cloudflare.com",
            "8.8.8.8"
        )
        
        $dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses}).ServerAddresses | Sort-Object -Unique
        Write-Log "Configured DNS Servers: $($dnsServers -join ', ')"
        
        foreach ($domain in $testDomains) {
            try {
                $result = Resolve-DnsName -Name $domain -ErrorAction Stop
                $resolvedIP = $result | Where-Object {$_.Type -eq "A"} | Select-Object -First 1
                if ($resolvedIP) {
                    Write-Log "  [+] $domain -> $($resolvedIP.IPAddress)" "SUCCESS"
                }
            }
            catch {
                Write-Log "  [-] Failed to resolve $domain : $($_.Exception.Message)" "ERROR"
            }
        }
        
        # Test DNS response times
        Write-Log "Testing DNS response times..."
        foreach ($dnsServer in $dnsServers) {
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Resolve-DnsName -Name "google.com" -Server $dnsServer -ErrorAction Stop | Out-Null
                $stopwatch.Stop()
                Write-Log "  DNS Server $dnsServer response time: $($stopwatch.ElapsedMilliseconds)ms"
            }
            catch {
                Write-Log "  DNS Server $dnsServer failed to respond" "ERROR"
            }
        }
    }
    catch {
        Write-Log "Error testing DNS resolution: $($_.Exception.Message)" "ERROR"
    }
}

# Port Connectivity Testing
# Port Connectivity Testing - Updated Version
function Test-PortConnectivity {
    Write-Log "=== PORT CONNECTIVITY TESTING ===" "SUCCESS"
    
    try {
        # Define test hosts for different protocols
        $testHosts = @{
            53 = @("1.1.1.1", "8.8.8.8", "9.9.9.9")  # DNS servers
            80 = @("httpbin.org", "example.com", "httpforever.com")  # HTTP sites
            443 = @("google.com", "github.com", "stackoverflow.com")  # HTTPS sites
            22 = @("github.com", "gitlab.com", "bitbucket.org")  # SSH Git hosts
            123 = @("time.nist.gov", "pool.ntp.org", "time.google.com")  # NTP servers
            135 = @()  # RPC - No reliable public test hosts
            445 = @()  # SMB - No reliable public test hosts  
            3389 = @()  # RDP - No reliable public test hosts
        }
        
        $commonPorts = @(
            @{Port=53; Service="DNS"; Protocol="TCP"; TestHosts=$testHosts[53]},
            @{Port=80; Service="HTTP"; Protocol="TCP"; TestHosts=$testHosts[80]},
            @{Port=443; Service="HTTPS"; Protocol="TCP"; TestHosts=$testHosts[443]},
            @{Port=22; Service="SSH"; Protocol="TCP"; TestHosts=$testHosts[22]},
            @{Port=123; Service="NTP"; Protocol="UDP"; TestHosts=$testHosts[123]},
            @{Port=135; Service="RPC"; Protocol="TCP"; TestHosts=$testHosts[135]},
            @{Port=445; Service="SMB"; Protocol="TCP"; TestHosts=$testHosts[445]},
            @{Port=3389; Service="RDP"; Protocol="TCP"; TestHosts=$testHosts[3389]}
        )
        
        # Get gateway for local network testing
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1
        
        Write-Log "Testing outbound connectivity (Internet-facing services):"
        
        # Test each port configuration
        foreach ($portConfig in $commonPorts) {
            if ($portConfig.TestHosts.Count -gt 0) {
                Write-Log "Testing $($portConfig.Service) (Port $($portConfig.Port)):"
                
                $successCount = 0
                $totalTests = [Math]::Min(3, $portConfig.TestHosts.Count)  # Test up to 3 hosts
                
                for ($i = 0; $i -lt $totalTests; $i++) {
                    $testHost = $portConfig.TestHosts[$i]
                    
                    try {
                        if ($portConfig.Protocol -eq "TCP") {
                            $result = Test-NetConnection -ComputerName $testHost -Port $portConfig.Port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction Stop
                            $status = if ($result) { "[+] OPEN" } else { "[-] BLOCKED" }
                            $color = if ($result) { "SUCCESS" } else { "WARN" }
                            Write-Log "  $testHost`:$($portConfig.Port) - $status" $color
                            
                            if ($result) { $successCount++ }
                        }
                        elseif ($portConfig.Protocol -eq "UDP" -and $portConfig.Service -eq "NTP") {
                            # Special handling for NTP
                            $ntpResult = Test-NTPConnectivity -Server $testHost
                            if ($ntpResult) {
                                Write-Log "  $testHost`:$($portConfig.Port) - [+] NTP RESPONSIVE" "SUCCESS"
                                $successCount++
                            }
                            else {
                                Write-Log "  $testHost`:$($portConfig.Port) - [-] NTP NO RESPONSE" "WARN"
                            }
                        }
                    }
                    catch {
                        Write-Log "  $testHost`:$($portConfig.Port) - [-] ERROR: $($_.Exception.Message)" "ERROR"
                    }
                }
                
                # Summary for this service
                if ($successCount -gt 0) {
                    Write-Log "  $($portConfig.Service) connectivity: [+] Available ($successCount/$totalTests hosts reachable)" "SUCCESS"
                }
                else {
                    Write-Log "  $($portConfig.Service) connectivity: [-] Blocked or filtered" "ERROR"
                }
            }
            else {
                Write-Log "$($portConfig.Service) (Port $($portConfig.Port)): [!] No public test hosts - requires local testing" "INFO"
            }
        }
        
        # Test local/internal services against gateway
        Write-Log "`nTesting local network services (against gateway $gateway):"
        
        $localServices = @(
            @{Port=135; Service="RPC"},
            @{Port=445; Service="SMB"}, 
            @{Port=3389; Service="RDP"}
        )
        
        foreach ($service in $localServices) {
            try {
                $result = Test-NetConnection -ComputerName $gateway -Port $service.Port -InformationLevel Quiet -WarningAction SilentlyContinue
                $status = if ($result) { "[+] OPEN" } else { "[-] CLOSED/FILTERED" }
                $color = if ($result) { "SUCCESS" } else { "INFO" }  # Not necessarily an error for gateway
                Write-Log "  Gateway $($service.Service) (Port $($service.Port)): $status" $color
            }
            catch {
                Write-Log "  Gateway $($service.Service) (Port $($service.Port)): [-] ERROR" "WARN"
            }
        }
        
        # Additional network service tests
        Test-AdditionalNetworkServices
    }
    catch {
        Write-Log "Error testing port connectivity: $($_.Exception.Message)" "ERROR"
    }
}

# NTP connectivity testing function
function Test-NTPConnectivity {
    param([string]$Server)
    
    try {
        # Create UDP client for NTP
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Connect($Server, 123)
        
        # NTP request packet (simplified)
        $ntpData = New-Object byte[] 48
        $ntpData[0] = 0x1B  # NTP version 3, client mode
        
        # Send NTP request
        $udpClient.Send($ntpData, $ntpData.Length) | Out-Null
        
        # Set timeout
        $udpClient.Client.ReceiveTimeout = 3000
        
        # Try to receive response
        $endpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $response = $udpClient.Receive([ref]$endpoint)
        
        $udpClient.Close()
        
        # If we got a response, NTP is working
        return ($response.Length -eq 48)
    }
    catch {
        if ($udpClient) { $udpClient.Close() }
        return $false
    }
}

# Test additional network services
function Test-AdditionalNetworkServices {
    Write-Log "`nTesting additional network services:"
    
    # Test ICMP (ping) - already covered in performance testing but worth mentioning
    Write-Log "ICMP (Ping): [+] Already tested in performance section" "INFO"
    
    # Test DHCP (already covered)
    Write-Log "DHCP: [+] Already tested in DHCP section" "INFO"
    
    # Test for common proxy ports
    $proxyPorts = @(8080, 3128, 8888)
    Write-Log "Testing common proxy ports against gateway:"
    
    $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1
    foreach ($port in $proxyPorts) {
        try {
            $result = Test-NetConnection -ComputerName $gateway -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            $status = if ($result) { "[+] OPEN" } else { "[-] CLOSED" }
            $color = if ($result) { "WARN" } else { "INFO" }  # Open proxy ports might be concerning
            Write-Log "  Proxy port $port`: $status" $color
        }
        catch {
            Write-Log "  Proxy port $port`: [-] ERROR" "WARN"
        }
    }
    
    # Test for mail ports (if requested)
    Test-MailPorts
}

# Test mail-related ports
function Test-MailPorts {
    Write-Log "`nTesting mail service ports:"
    
    $mailTests = @(
        @{Host="smtp.gmail.com"; Port=587; Service="SMTP (TLS)"},
        @{Host="smtp.gmail.com"; Port=465; Service="SMTP (SSL)"},
        @{Host="imap.gmail.com"; Port=993; Service="IMAP (SSL)"},
        @{Host="pop.gmail.com"; Port=995; Service="POP3 (SSL)"}
    )
    
    foreach ($test in $mailTests) {
        try {
            $result = Test-NetConnection -ComputerName $test.Host -Port $test.Port -InformationLevel Quiet -WarningAction SilentlyContinue
            $status = if ($result) { "[+] OPEN" } else { "[-] BLOCKED" }
            $color = if ($result) { "SUCCESS" } else { "WARN" }
            Write-Log "  $($test.Service) ($($test.Host):$($test.Port)): $status" $color
        }
        catch {
            Write-Log "  $($test.Service): [-] ERROR" "ERROR"
        }
    }
}
# Network Performance Testing
# Network Performance Testing - Updated Version
function Test-NetworkPerformance {
    Write-Log "=== NETWORK PERFORMANCE TESTING ===" "SUCCESS"
    
    try {
        $testHosts = @(
            @{Host="8.8.8.8"; Name="Google DNS"},
            @{Host="1.1.1.1"; Name="Cloudflare DNS"},
            @{Host="9.9.9.9"; Name="Quad9 DNS"}
        )
        
        $allResults = @()
        
        foreach ($testHost in $testHosts) {
            Write-Log "Testing connectivity to $($testHost.Host) ($($testHost.Name))"
            try {
                $pingResult = Test-Connection -ComputerName $testHost.Host -Count 4 -ErrorAction Stop
                $avgLatency = ($pingResult.ResponseTime | Measure-Object -Average).Average
                $minLatency = ($pingResult.ResponseTime | Measure-Object -Minimum).Minimum
                $maxLatency = ($pingResult.ResponseTime | Measure-Object -Maximum).Maximum
                $packetLoss = (4 - $pingResult.Count) / 4 * 100
                
                Write-Log "  Average Latency: $([math]::Round($avgLatency, 2))ms"
                Write-Log "  Min/Max Latency: $([math]::Round($minLatency, 2))ms / $([math]::Round($maxLatency, 2))ms"
                Write-Log "  Packet Loss: $packetLoss%"
                
                # Calculate jitter (variation in latency)
                if ($pingResult.Count -gt 1) {
                    $jitter = ($pingResult.ResponseTime | Measure-Object -StandardDeviation).StandardDeviation
                    Write-Log "  Jitter (std dev): $([math]::Round($jitter, 2))ms"
                    
                    if ($jitter -gt 10) {
                        Write-Log "  HIGH JITTER DETECTED - May affect VoIP/video calls!" "WARN"
                    }
                }
                
                # Performance warnings
                if ($avgLatency -gt 100) {
                    Write-Log "  HIGH LATENCY DETECTED!" "WARN"
                }
                if ($avgLatency -gt 200) {
                    Write-Log "  VERY HIGH LATENCY - Check network congestion!" "ERROR"
                }
                if ($packetLoss -gt 0) {
                    Write-Log "  PACKET LOSS DETECTED!" "WARN"
                }
                if ($packetLoss -gt 5) {
                    Write-Log "  SIGNIFICANT PACKET LOSS - Network issue likely!" "ERROR"
                }
                
                # Store results for analysis
                $allResults += @{
                    Host = $testHost.Host
                    Name = $testHost.Name
                    AvgLatency = $avgLatency
                    MinLatency = $minLatency
                    MaxLatency = $maxLatency
                    PacketLoss = $packetLoss
                    Jitter = if ($pingResult.Count -gt 1) { ($pingResult.ResponseTime | Measure-Object -StandardDeviation).StandardDeviation } else { 0 }
                }
            }
            catch {
                Write-Log "  Failed to ping $($testHost.Host) : $($_.Exception.Message)" "ERROR"
            }
        }
        
        # Analyze results across all hosts
        if ($allResults.Count -gt 0) {
            Measure-NetworkPerformanceAnalysis -Results $allResults
        }
        
        # Test gateway performance specifically
        Test-GatewayPerformance
        
        # Test DNS performance (different from connectivity)
        Test-DNSPerformance
        
        # Test HTTP response time (more practical than large ping)
        Test-HTTPPerformance
        
    }
    catch {
        Write-Log "Error testing network performance: $($_.Exception.Message)" "ERROR"
    }
}

function Measure-NetworkPerformanceAnalysis {
    param($Results)
    
    Write-Log "`nNetwork Performance Analysis:"
    
    $avgLatencyOverall = ($Results | Measure-Object -Property AvgLatency -Average).Average
    $avgPacketLoss = ($Results | Measure-Object -Property PacketLoss -Average).Average
    $avgJitter = ($Results | Measure-Object -Property Jitter -Average).Average
    
    Write-Log "  Overall Average Latency: $([math]::Round($avgLatencyOverall, 2))ms"
    Write-Log "  Overall Packet Loss: $([math]::Round($avgPacketLoss, 2))%"
    Write-Log "  Overall Jitter: $([math]::Round($avgJitter, 2))ms"
    
    # Performance rating
    $performanceRating = Get-PerformanceRating -Latency $avgLatencyOverall -PacketLoss $avgPacketLoss -Jitter $avgJitter
    Write-Log "  Performance Rating: $($performanceRating.Rating)" $performanceRating.Color
    Write-Log "  $($performanceRating.Description)"
    
    # Check for routing issues (significant differences between hosts)
    $latencyVariation = ($Results | Measure-Object -Property AvgLatency -Maximum).Maximum - ($Results | Measure-Object -Property AvgLatency -Minimum).Minimum
    if ($latencyVariation -gt 50) {
        Write-Log "  ROUTING INCONSISTENCY: Large latency variation between hosts ($([math]::Round($latencyVariation, 2))ms)" "WARN"
    }
}

function Get-PerformanceRating {
    param($Latency, $PacketLoss, $Jitter)
    
    if ($PacketLoss -gt 5) {
        return @{Rating="Poor"; Color="ERROR"; Description="High packet loss will affect all applications"}
    }
    elseif ($Latency -gt 200) {
        return @{Rating="Poor"; Color="ERROR"; Description="High latency will impact interactive applications"}
    }
    elseif ($Jitter -gt 20) {
        return @{Rating="Poor"; Color="ERROR"; Description="High jitter will impact real-time applications (VoIP, video)"}
    }
    elseif ($Latency -gt 100 -or $PacketLoss -gt 1 -or $Jitter -gt 10) {
        return @{Rating="Fair"; Color="WARN"; Description="Some applications may experience issues"}
    }
    elseif ($Latency -gt 50 -or $Jitter -gt 5) {
        return @{Rating="Good"; Color="SUCCESS"; Description="Good performance for most applications"}
    }
    else {
        return @{Rating="Excellent"; Color="SUCCESS"; Description="Excellent performance for all applications"}
    }
}

function Test-GatewayPerformance {
    Write-Log "`nTesting gateway performance:"
    
    try {
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1
        
        if ($gateway) {
            Write-Log "Testing gateway: $gateway"
            $gatewayPing = Test-Connection -ComputerName $gateway -Count 4 -ErrorAction Stop
            $gatewayLatency = ($gatewayPing.ResponseTime | Measure-Object -Average).Average
            
            Write-Log "  Gateway Latency: $([math]::Round($gatewayLatency, 2))ms"
            
            if ($gatewayLatency -gt 10) {
                Write-Log "  HIGH GATEWAY LATENCY - Local network congestion!" "WARN"
            }
            if ($gatewayLatency -gt 50) {
                Write-Log "  VERY HIGH GATEWAY LATENCY - Check local network!" "ERROR"
            }
        }
        else {
            Write-Log "  Could not determine gateway" "WARN"
        }
    }
    catch {
        Write-Log "  Gateway test failed: $($_.Exception.Message)" "ERROR"
    }
}

function Test-DNSPerformance {
    Write-Log "`nTesting DNS resolution performance:"
    
    $testDomains = @("google.com", "microsoft.com", "github.com")
    $dnsServer = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses} | Select-Object -First 1).ServerAddresses[0]
    
    $dnsTimes = @()
    
    foreach ($domain in $testDomains) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Resolve-DnsName -Name $domain -Server $dnsServer -ErrorAction Stop | Out-Null
            $stopwatch.Stop()
            
            $responseTime = $stopwatch.ElapsedMilliseconds
            $dnsTimes += $responseTime
            Write-Log "  $domain`: $($responseTime)ms"
        }
        catch {
            Write-Log "  $domain`: DNS resolution failed" "ERROR"
        }
    }
    
    if ($dnsTimes.Count -gt 0) {
        $avgDNSTime = ($dnsTimes | Measure-Object -Average).Average
        Write-Log "  Average DNS Response Time: $([math]::Round($avgDNSTime, 2))ms"
        
        if ($avgDNSTime -gt 100) {
            Write-Log "  SLOW DNS RESOLUTION - Consider changing DNS servers!" "WARN"
        }
    }
}

function Test-HTTPPerformance {
    Write-Log "`nTesting HTTP response times:"
    
    $webTests = @(
        @{Url="http://httpbin.org/get"; Name="HTTP Test"},
        @{Url="https://www.google.com"; Name="HTTPS Test"}
    )
    
    foreach ($test in $webTests) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $test.Url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            $stopwatch.Stop()
            
            $responseTime = $stopwatch.ElapsedMilliseconds
            Write-Log "  $($test.Name): $($responseTime)ms (Status: $($response.StatusCode))"
            
            if ($responseTime -gt 3000) {
                Write-Log "    SLOW WEB RESPONSE - May indicate bandwidth issues!" "WARN"
            }
        }
        catch {
            Write-Log "  $($test.Name): Failed - $($_.Exception.Message)" "ERROR"
        }
    }
}

# Network Discovery and Scanning
function Invoke-NetworkDiscovery {
    param([string]$Subnet)
    
    Write-Log "=== NETWORK DISCOVERY ===" "SUCCESS"
    
    try {
        if (-not $Subnet) {
            # Auto-detect subnet
            $netConfig = Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up"} | Select-Object -First 1
            if ($netConfig) {
                $ip = $netConfig.IPv4Address.IPAddress
                $prefix = $netConfig.IPv4Address.PrefixLength
                $networkAddr = $ip.Substring(0, $ip.LastIndexOf('.'))
                $Subnet = "$networkAddr.0/$prefix"
            }
        }
        
        if ($Subnet) {
            Write-Log "Scanning subnet: $Subnet"
            
            # Extract base network for simple scanning
            $baseNetwork = $Subnet.Split('/')[0]
            $networkBase = $baseNetwork.Substring(0, $baseNetwork.LastIndexOf('.'))
            
            Write-Log "Discovering active hosts (this may take a moment)..."
            $activeHosts = @()
            
            # Parallel ping sweep for better performance
            $jobs = @()
            for ($i = 1; $i -le 254; $i++) {
                $targetIP = "$networkBase.$i"
                $jobs += Start-Job -ScriptBlock {
                    param($ip)
                    if (Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1) {
                        return $ip
                    }
                } -ArgumentList $targetIP
            }
            
            # Wait for jobs with timeout
            $timeout = (Get-Date).AddSeconds($ScanTimeout)
            while ((Get-Date) -lt $timeout -and ($jobs | Where-Object {$_.State -eq "Running"}).Count -gt 0) {
                Start-Sleep -Milliseconds 500
            }
            
            # Collect results
            foreach ($job in $jobs) {
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                if ($result) {
                    $activeHosts += $result
                    Write-Log "  Active host found: $result"
                }
                Remove-Job -Job $job -Force
            }
            
            Write-Log "Discovery complete. Found $($activeHosts.Count) active hosts."
            
            # Try to identify device types for discovered hosts
            if ($activeHosts.Count -gt 0 -and $DeepScan) {
                Write-Log "Performing deep scan on discovered hosts..."
                foreach ($hostIP in $activeHosts) {
                    try {
                        $hostname = [System.Net.Dns]::GetHostEntry($hostIP).HostName
                        Write-Log "  $hostIP -> $hostname"
                    }
                    catch {
                        Write-Log "  $hostIP -> No reverse DNS"
                    }
                }
            }
        }
        else {
            Write-Log "Could not determine subnet for discovery" "WARN"
        }
    }
    catch {
        Write-Log "Error during network discovery: $($_.Exception.Message)" "ERROR"
    }
}

# Routing Table Analysis
function Test-RoutingTable {
    Write-Log "=== ROUTING TABLE ANALYSIS ===" "SUCCESS"
    
    try {
        $routes = Get-NetRoute -AddressFamily IPv4 | Sort-Object RouteMetric
        $defaultRoutes = $routes | Where-Object {$_.DestinationPrefix -eq "0.0.0.0/0"}
        
        Write-Log "Default Routes:"
        foreach ($route in $defaultRoutes) {
            Write-Log "  Gateway: $($route.NextHop) | Interface: $($route.InterfaceAlias) | Metric: $($route.RouteMetric)"
        }
        
        if ($defaultRoutes.Count -gt 1) {
            Write-Log "Multiple default routes detected - check for routing conflicts!" "WARN"
        }
        
        # Check for unusual routes
        $suspiciousRoutes = $routes | Where-Object {
            $_.DestinationPrefix -ne "0.0.0.0/0" -and 
            $_.DestinationPrefix -notlike "127.*" -and 
            $_.DestinationPrefix -notlike "224.*" -and
            $_.DestinationPrefix -notlike "*::*" -and
            $_.NextHop -ne "0.0.0.0"
        }
        
        if ($suspiciousRoutes) {
            Write-Log "Static/Custom Routes Found:"
            foreach ($route in $suspiciousRoutes | Select-Object -First 10) {
                Write-Log "  $($route.DestinationPrefix) -> $($route.NextHop)"
            }
        }
    }
    catch {
        Write-Log "Error analyzing routing table: $($_.Exception.Message)" "ERROR"
    }
}

# Generate Summary Report
function Get-Summary {
    Write-Log "=== DIAGNOSTIC SUMMARY ===" "SUCCESS"
    
    try {
        $logContent = Get-Content $LogPath -ErrorAction SilentlyContinue
        if ($logContent) {
            $errors = ($logContent | Select-String "\[ERROR\]").Count
            $warnings = ($logContent | Select-String "\[WARN\]").Count
            
            Write-Log "Errors Found: $errors"
            Write-Log "Warnings Found: $warnings"
            
            if ($errors -eq 0 -and $warnings -eq 0) {
                Write-Log "[+] No major issues detected!" "SUCCESS"
            }
            elseif ($errors -eq 0) {
                Write-Log "[!] Minor issues detected - review warnings" "WARN"
            }
            else {
                Write-Log "[-] Critical issues detected - review errors immediately" "ERROR"
            }
        }
        
        Write-Log "Full log available at: $LogPath"
        Write-Log "Diagnostic completed at $(Get-Date)"
    }
    catch {
        Write-Log "Error generating summary: $($_.Exception.Message)" "ERROR"
    }
}

# Main execution
try {
    Write-Host "`n=== MSP Network Diagnostics Tool ===" -ForegroundColor Cyan
    Write-Host "Starting comprehensive network analysis...`n" -ForegroundColor Cyan
    
    # Core tests (always run)
    Get-NetworkAdapterInfo
    Test-DHCPServers
    Test-DNSResolution
    Test-NetworkPerformance
    Test-RoutingTable
    
    if (-not $QuickScan) {
        Test-MulticastTraffic
        Test-PortConnectivity
        Invoke-NetworkDiscovery -Subnet $TargetSubnet
    }
    
    Get-Summary
    
    Write-Host "`n=== Diagnostics Complete ===" -ForegroundColor Green
    Write-Host "Log file saved to: $LogPath" -ForegroundColor Green
    
    # Ask if user wants to open log file
    $openLog = Read-Host "`nWould you like to open the log file? (y/n)"
    if ($openLog -eq 'y' -or $openLog -eq 'Y') {
        if (Test-Path $LogPath) {
            Start-Process notepad.exe -ArgumentList $LogPath
        }
    }
}
catch {
    Write-Log "Critical error during diagnostics: $($_.Exception.Message)" "ERROR"
    Write-Host "A critical error occurred. Check the log file for details." -ForegroundColor Red
}
finally {
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}