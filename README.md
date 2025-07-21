# API Performance Testing Tool

A PowerShell script for testing and monitoring API response times with configurable settings and detailed performance statistics.

## Features

- **Batch Testing**: Run multiple tests and get statistical analysis
- **Continuous Monitoring**: Monitor API performance over time
- **Configurable Settings**: Easy configuration at the top of the script
- **Detailed Reporting**: Response times, status codes, content length
- **Performance Rating**: Automatic categorization of API performance
- **CSV Export**: Optional export of results for further analysis
- **Error Handling**: Robust error handling and reporting

## Configuration

All settings can be configured in the `$Config` section at the top of the script:

### API Testing Settings
- `DefaultUrl`: The API endpoint to test
- `DefaultTestCount`: Number of tests to run (default: 5)
- `TimeoutSeconds`: Request timeout in seconds (default: 30)
- `DelayBetweenTestsMs`: Delay between individual tests in milliseconds (default: 500)

### Continuous Monitoring Settings
- `MonitoringIntervalSeconds`: How often to test in continuous mode (default: 10)
- `MonitoringDurationMinutes`: How long to run continuous monitoring (default: 5)

### Output Settings
- `ShowDetailedResults`: Show individual test results (default: true)
- `ShowSummaryStats`: Show performance summary (default: true)
- `ExportToCSV`: Automatically export results to CSV (default: false)
- `CSVPath`: Path for CSV export file

## Usage

### Basic Usage
```powershell
# Run with default settings (5 tests)
.\measureResponseTime.ps1

# Run with specific number of tests
.\measureResponseTime.ps1 -TestCount 20

# Test a different URL
.\measureResponseTime.ps1 -Url "https://api.example.com/endpoint" -TestCount 10

# Run continuous monitoring
.\measureResponseTime.ps1 -ContinuousMode
```

### Advanced Usage
```powershell
# Load functions and run manually
. .\measureResponseTime.ps1
Measure-APILoading -NumberOfTests 50
Monitor-APILoading -DurationMinutes 10 -IntervalSeconds 5

# Access last test results
$global:LastTestResults | Where-Object Success -eq $false
```

## Output

### Batch Test Output
```
Testing API Loading Performance for: https://google.com
Running 5 tests...

Test 1 of 5
  Status: 200
  Response Time: 117 ms
  Content Length: 26986 bytes

=== PERFORMANCE SUMMARY ===
Total Tests: 5
Successful Tests: 5 / 5
Average Response Time: 102.8 ms
Minimum Response Time: 93 ms
Maximum Response Time: 117 ms
Success Rate: 100%
Performance Rating: Good (100-300ms)
```

### Continuous Monitoring Output
```
Starting continuous monitoring for 5 minutes...
Testing every 10 seconds
Press Ctrl+C to stop monitoring

[14:30:15] Test #1
  Response Time: 105 ms | Status: 200
[14:30:25] Test #2
  Response Time: 98 ms | Status: 200
```

## Performance Ratings

The script automatically categorizes API performance:
- **Excellent**: < 100ms average response time
- **Good**: 100-300ms average response time  
- **Fair**: 300ms-1s average response time
- **Poor**: > 1s average response time

Here's the updated CSV Export section for the README:

## CSV Export

### How to Enable CSV Export

**Method 1: Edit the script configuration**
Open `measureResponseTime.ps1` and change this line in the `$Config` section:
```powershell
ExportToCSV = $true              # Change from $false to $true
```

**Method 2: Manual export after running tests**
```powershell
.\measureResponseTime.ps1 -TestCount 20
$global:LastTestResults | Export-Csv -Path "MyResults.csv" -NoTypeInformation
```

### CSV File Contents

When `ExportToCSV` is enabled, results include:
- TestNumber
- Timestamp
- ResponseTime_MS
- StatusCode
- ContentLength
- Success (boolean)
- ErrorMessage
- URL

**Example CSV output:**
```csv
TestNumber,Timestamp,ResponseTime_MS,StatusCode,ContentLength,Success,ErrorMessage,URL
1,2024-01-15 14:30:25,117,200,26986,True,,https://google.com
2,2024-01-15 14:30:26,93,200,26986,True,,https://google.com
```

## Authentication Support

### Bearer Token Authentication

The script supports Bearer token authentication for APIs that require it.

#### Method 1: Configure in Script
Edit the `$Config` section in the script:
```powershell
# Authentication Configuration
BearerToken = "your-token-here"
```

### Method 2: Command Line Parameter
```PowerShell
.\measureResponseTime.ps1 -BearerToken "your-token-here" -TestCount 10
```

## Functions Available

- `Measure-APILoading`: Run batch performance tests
- `Monitor-APILoading`: Run continuous monitoring
- `Show-PerformanceStats`: Display performance statistics

## Requirements

- PowerShell 3.0 or later
- Internet connectivity to reach the API endpoint
- Appropriate permissions to make HTTP requests

## Troubleshooting

### Common Issues

1. **Timeout Errors**: Increase `TimeoutSeconds` in configuration
2. **Access Denied**: Check firewall and proxy settings
3. **SSL/TLS Errors**: Ensure endpoint has valid certificates

### Enable More Verbose Output
Set `ShowDetailedResults = $true` in the configuration section.

### Disable Progress Bar
Set `ShowDetailedResults = $true` to see individual test results instead of progress bar.

## Examples

```powershell
# Quick 10-test performance check
.\measureResponseTime.ps1 -TestCount 10

# Monitor API for 30 minutes, testing every 30 seconds
# (Modify config: MonitoringDurationMinutes = 30, MonitoringIntervalSeconds = 30)
.\measureResponseTime.ps1 -ContinuousMode

# Test multiple URLs
.\measureResponseTime.ps1 -Url "https://api1.example.com"
.\measureResponseTime.ps1 -Url "https://api2.example.com"
```

## License

This script is provided as-is for educational and testing purposes.