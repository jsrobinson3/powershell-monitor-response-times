# PowerShell Network & Performance Monitoring Tools

A collection of PowerShell scripts for network diagnostics and performance monitoring, designed for MSPs and IT professionals.

## Tools Included

### 🌐 Network Diagnostics Tool
**Location**: `/network-diagnostics/`

Comprehensive network testing script for on-site diagnostics including:
- DHCP server detection and conflict identification
- Multicast storm detection
- DNS resolution testing
- Port connectivity testing
- Network discovery and scanning
- Performance testing and analysis

**Quick Start**:
```powershell
.\network-diagnostics\NetworkDiagnostics.ps1
```

### 📊 API Performance Testing Tool
**Location**: `/api-performance-testing/`

PowerShell script for testing and monitoring API response times with configurable settings and detailed performance statistics.

**Features**:
- Batch testing with statistical analysis
- Continuous monitoring
- CSV export capabilities
- Authentication support
- Performance rating system

**Quick Start**:
```powershell
.\api-performance-testing\measureResponseTime.ps1 -TestCount 10
```

## Requirements

- PowerShell 3.0 or later
- Administrative privileges (recommended for network diagnostics)
- Internet connectivity for external connectivity tests

## Usage Examples

### Network Diagnostics
```powershell
# Quick network scan
.\network-diagnostics\NetworkDiagnostics.ps1 -QuickScan

# Deep scan with network discovery
.\network-diagnostics\NetworkDiagnostics.ps1 -DeepScan

# Scan specific subnet
.\network-diagnostics\NetworkDiagnostics.ps1 -TargetSubnet "192.168.1.0/24"
```

### API Performance Testing
```powershell
# Basic performance test
.\api-performance-testing\measureResponseTime.ps1 -TestCount 20

# Continuous monitoring
.\api-performance-testing\measureResponseTime.ps1 -ContinuousMode

# Test with authentication
.\api-performance-testing\measureResponseTime.ps1 -BearerToken "your-token" -TestCount 10
```

## Contributing

Feel free to contribute by:
- Adding new diagnostic tools
- Improving existing scripts
- Reporting bugs or issues
- Suggesting new features

## License

This collection is provided as-is for educational and professional use.