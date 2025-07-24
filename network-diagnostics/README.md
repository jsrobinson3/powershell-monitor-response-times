# Network Diagnostics Tool

A comprehensive PowerShell script designed for MSP field technicians to diagnose common network issues during on-site visits.

## Features

- **DHCP Conflict Detection**: Identifies multiple DHCP servers on the network
- **Multicast Storm Detection**: Monitors for excessive multicast/broadcast traffic
- **DNS Resolution Testing**: Validates DNS functionality and response times
- **Port Connectivity Testing**: Tests common service ports (HTTP, HTTPS, RDP, etc.)
- **Network Discovery**: Scans for active hosts on the network
- **Performance Testing**: Measures latency and packet loss
- **Routing Analysis**: Checks for routing conflicts and unusual routes
- **Comprehensive Logging**: Detailed logs with timestamps and severity levels

## Usage

### Basic Usage
```powershell
# Run standard diagnostics
.\NetworkDiagnostics.ps1

# Quick scan (basic tests only)
.\NetworkDiagnostics.ps1 -QuickScan

# Deep scan with network discovery
.\NetworkDiagnostics.ps1 -DeepScan
```

### Advanced Usage
```powershell
# Scan specific subnet
.\NetworkDiagnostics.ps1 -TargetSubnet "192.168.1.0/24"

# Custom log location
.\NetworkDiagnostics.ps1 -LogPath "D:\Logs\NetworkTest.log"

# Extended timeout for large networks
.\NetworkDiagnostics.ps1 -DeepScan -ScanTimeout 60
```

## Command Line Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-QuickScan` | Run basic tests only | False |
| `-DeepScan` | Include network discovery and detailed scanning | False |
| `-LogPath` | Custom log file location | `C:\Temp\NetworkDiag_[timestamp].log` |
| `-TargetSubnet` | Specific subnet to scan | Auto-detected |
| `-ScanTimeout` | Network discovery timeout (seconds) | 30 |

## Tests Performed

### Always Run (Core Tests)
- Network adapter information
- DHCP server detection
- DNS resolution testing
- Network performance testing
- Routing table analysis

### Standard Tests (Default)
- Multicast traffic monitoring
- Port connectivity testing
- Basic network discovery

### Deep Scan Tests
- Extended network discovery
- Reverse DNS lookups
- Detailed host identification

## Output and Logging

### Console Output
The script provides color-coded output:
- **Green**: Success messages and normal operations
- **Yellow**: Warnings and potential issues
- **Red**: Errors and critical problems
- **White**: Informational messages

### Log Files
- Detailed timestamped logs are saved automatically
- Log location is displayed at script start
- Option to open log file in Notepad after completion

### Issue Detection
The script automatically identifies:
- DHCP conflicts (multiple servers)
- Multicast/broadcast storms
- DNS resolution failures
- High latency or packet loss
- Routing conflicts
- Blocked ports or connectivity issues

## Sample Output

```
=== MSP Network Diagnostics Tool ===
Starting comprehensive network analysis...

=== NETWORK ADAPTER INFORMATION ===
Adapter: Wi-Fi - Intel(R) Wi-Fi 6 AX201 160MHz
  Status: Up | Speed: 1 Gbps | MAC: 00:11:22:33:44:55
  IP: 192.168.1.100/24
  Gateway: 192.168.1.1

=== DHCP SERVER DETECTION ===
Testing DHCP on interface: Wi-Fi
  DHCP Server detected: 192.168.1.1
Single DHCP server detected: 192.168.1.1

=== DNS RESOLUTION TESTING ===
Configured DNS Servers: 8.8.8.8, 8.8.4.4
  [+] google.com -> 142.250.191.14
  [+] microsoft.com -> 20.112.52.29
  [+] cloudflare.com -> 104.16.124.96
```

## Troubleshooting

### Common Issues

1. **Access Denied Errors**: Run PowerShell as Administrator
2. **Execution Policy**: Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. **Firewall Blocking**: Ensure Windows Firewall allows PowerShell network access
4. **Network Discovery Fails**: Check if ICMP is blocked by firewall

### Performance Considerations

- Network discovery can take time on large networks
- Use `-ScanTimeout` parameter to adjust for network size
- `-QuickScan` mode for faster results when time is limited

## Requirements

- PowerShell 3.0 or later
- Administrative privileges (recommended)
- Network connectivity
- Windows 7/Server 2008 R2 or later

## Field Usage Tips

1. **Run as Administrator** for full functionality
2. **Use QuickScan** for initial assessment
3. **Enable Deep Scan** when investigating specific issues
4. **Check log files** for detailed analysis
5. **Document findings** using the generated log files

## MSP Integration

This tool is designed to integrate with MSP workflows:
- Standardized logging format
- Automated issue detection
- Professional reporting
- Configurable timeout settings
- Portable execution (no installation required)
