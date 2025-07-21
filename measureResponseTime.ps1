<#
.SYNOPSIS
    API Performance Testing and Monitoring Tool

.DESCRIPTION
    This script measures API response times and provides performance statistics.
    It can run single batch tests or continuous monitoring.

.PARAMETER TestCount
    Number of tests to run in batch mode (overrides config)

.PARAMETER Url
    URL to test (overrides config)

.PARAMETER ContinuousMode
    Switch to run in continuous monitoring mode

.EXAMPLE
    .\measureResponseTime.ps1 -TestCount 10
    .\measureResponseTime.ps1 -ContinuousMode
    .\measureResponseTime.ps1 -Url "https://example.com/api" -TestCount 5

.NOTES
    Author: Sumner Robinson
    Version: 1.0
    Created: 2025-07-21
#>

param(
    [int]$TestCount,
    [string]$Url,
    [switch]$ContinuousMode,
    [string]$BearerToken
)

# ===== CONFIGURATION SECTION =====
$Config = @{
    # API Testing Configuration
    DefaultUrl = "https://google.com"
    DefaultTestCount = 5
    TimeoutSeconds = 30
    DelayBetweenTestsMs = 500  # Milliseconds to wait between individual tests
    
    # Authentication Configuration
    BearerToken = ""              # Leave empty for no authentication, or add your token
    # Example: BearerToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    
    # Continuous Monitoring Configuration
    MonitoringIntervalSeconds = 10    # How often to test in continuous mode
    MonitoringDurationMinutes = 5     # How long to run continuous monitoring
    
    # Output Configuration
    ShowDetailedResults = $true       # Show individual test results
    ShowSummaryStats = $true          # Show performance summary
    ExportToCSV = $false             # Automatically export results to CSV
    CSVPath = "API_Performance_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    # Display Colors
    Colors = @{
        Header = "Green"
        Info = "Yellow"
        TestNumber = "Cyan"
        Success = "Green"
        Error = "Red"
        Summary = "Magenta"
        Warning = "Yellow"
    }
}


# Override config with parameters if provided
if ($TestCount) { $Config.DefaultTestCount = $TestCount }
if ($Url) { $Config.DefaultUrl = $Url }
if ($BearerToken) { $Config.BearerToken = $BearerToken }

# ===== FUNCTIONS =====

function Get-AuthHeaders {
    param()
    
    $headers = @{}
    
    if (-not [string]::IsNullOrWhiteSpace($Config.BearerToken)) {
        $headers["Authorization"] = "Bearer $($Config.BearerToken)"
        Write-Verbose "Using Bearer token authentication"
    }
    
    return $headers
}

function Measure-APILoading {
    param(
        [string]$TestUrl = $Config.DefaultUrl,
        [int]$NumberOfTests = $Config.DefaultTestCount,
        [int]$TimeoutSec = $Config.TimeoutSeconds
    )
    
    $authHeaders = Get-AuthHeaders
    $authStatus = if ($authHeaders.Count -gt 0) { " (with Bearer token)" } else { "" }
    
    Write-Host "Testing API Loading Performance for: $TestUrl$authStatus" -ForegroundColor $Config.Colors.Header
    Write-Host "Running $NumberOfTests tests..." -ForegroundColor $Config.Colors.Info
    Write-Host ""
    
    $results = @()
    
    for ($i = 1; $i -le $NumberOfTests; $i++) {
        if ($Config.ShowDetailedResults) {
            Write-Host "Test $i of $NumberOfTests" -ForegroundColor $Config.Colors.TestNumber
        }
        
        try {
            # Measure the time for the web request
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $requestParams = @{
                Uri = $TestUrl
                Method = "GET"
                TimeoutSec = $TimeoutSec
                ErrorAction = "Stop"
            }
            
            if ($authHeaders.Count -gt 0) {
                $requestParams.Headers = $authHeaders
            }
            
            $response = Invoke-WebRequest @requestParams
            
            $stopwatch.Stop()
            $responseTime = $stopwatch.ElapsedMilliseconds
            
            # Create result object
            $result = [PSCustomObject]@{
                TestNumber = $i
                Timestamp = Get-Date
                ResponseTime_MS = $responseTime
                StatusCode = $response.StatusCode
                ContentLength = $response.Content.Length
                Success = $true
                ErrorMessage = $null
                URL = $TestUrl
                AuthenticationUsed = ($authHeaders.Count -gt 0)
            }
            
            if ($Config.ShowDetailedResults) {
                Write-Host "  Status: $($response.StatusCode)" -ForegroundColor $Config.Colors.Success
                Write-Host "  Response Time: $responseTime ms" -ForegroundColor $Config.Colors.Success
                Write-Host "  Content Length: $($response.Content.Length) bytes" -ForegroundColor $Config.Colors.Success
            }
            else {
                Write-Progress -Activity "Testing API Performance" -Status "Test $i of $NumberOfTests - $responseTime ms" -PercentComplete (($i / $NumberOfTests) * 100)
            }
            
        }
        catch {
            $stopwatch.Stop()
            $result = [PSCustomObject]@{
                TestNumber = $i
                Timestamp = Get-Date
                ResponseTime_MS = $stopwatch.ElapsedMilliseconds
                StatusCode = $null
                ContentLength = 0
                Success = $false
                ErrorMessage = $_.Exception.Message
                URL = $TestUrl
                AuthenticationUsed = ($authHeaders.Count -gt 0)
            }
            
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor $Config.Colors.Error
            
            # Check if it's an authentication error
            if ($_.Exception.Message -match "401|Unauthorized" -and $authHeaders.Count -eq 0) {
                Write-Host "  Hint: This API might require authentication. Try adding a Bearer token." -ForegroundColor $Config.Colors.Warning
            }
        }
        
        $results += $result
        
        if ($Config.ShowDetailedResults) {
            Write-Host ""
        }
        
        # Small delay between requests (except for last test)
        if ($i -lt $NumberOfTests) {
            Start-Sleep -Milliseconds $Config.DelayBetweenTestsMs
        }
    }
    
    # Clear progress bar if it was used
    if (-not $Config.ShowDetailedResults) {
        Write-Progress -Activity "Testing API Performance" -Completed
    }
    
    # Calculate and display statistics
    if ($Config.ShowSummaryStats) {
        Show-PerformanceStats -Results $results
    }
    
    # Export to CSV if configured
    if ($Config.ExportToCSV) {
        $results | Export-Csv -Path $Config.CSVPath -NoTypeInformation
        Write-Host "Results exported to: $($Config.CSVPath)" -ForegroundColor $Config.Colors.Info
    }
    
    return $results
}

function Monitor-APILoading {
    param(
        [string]$TestUrl = $Config.DefaultUrl,
        [int]$IntervalSeconds = $Config.MonitoringIntervalSeconds,
        [int]$DurationMinutes = $Config.MonitoringDurationMinutes
    )
    
    $authHeaders = Get-AuthHeaders
    $authStatus = if ($authHeaders.Count -gt 0) { " (with Bearer token)" } else { "" }
    
    Write-Host "Starting continuous monitoring for $DurationMinutes minutes...$authStatus" -ForegroundColor $Config.Colors.Header
    Write-Host "Testing every $IntervalSeconds seconds" -ForegroundColor $Config.Colors.Info
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor $Config.Colors.Warning
    Write-Host ""
    
    $endTime = (Get-Date).AddMinutes($DurationMinutes)
    $testNumber = 1
    $results = @()
    
    while ((Get-Date) -lt $endTime) {
        Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] Test #$testNumber" -ForegroundColor $Config.Colors.TestNumber
        
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $requestParams = @{
                Uri = $TestUrl
                Method = "GET"
                TimeoutSec = $Config.TimeoutSeconds
                ErrorAction = "Stop"
            }
            
            if ($authHeaders.Count -gt 0) {
                $requestParams.Headers = $authHeaders
            }
            
            $response = Invoke-WebRequest @requestParams
            $stopwatch.Stop()
            
            $result = [PSCustomObject]@{
                TestNumber = $testNumber
                Timestamp = Get-Date
                ResponseTime_MS = $stopwatch.ElapsedMilliseconds
                StatusCode = $response.StatusCode
                ContentLength = $response.Content.Length
                Success = $true
                ErrorMessage = $null
                URL = $TestUrl
                AuthenticationUsed = ($authHeaders.Count -gt 0)
            }
            
            Write-Host "  Response Time: $($stopwatch.ElapsedMilliseconds) ms | Status: $($response.StatusCode)" -ForegroundColor $Config.Colors.Success
        }
        catch {
            $result = [PSCustomObject]@{
                TestNumber = $testNumber
                Timestamp = Get-Date
                ResponseTime_MS = $null
                StatusCode = $null
                ContentLength = 0
                Success = $false
                ErrorMessage = $_.Exception.Message
                URL = $TestUrl
                AuthenticationUsed = ($authHeaders.Count -gt 0)
            }
            
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor $Config.Colors.Error
        }
        
        $results += $result
        $testNumber++
        Start-Sleep -Seconds $IntervalSeconds
    }
    
    Write-Host "`nMonitoring completed!" -ForegroundColor $Config.Colors.Header
    Show-PerformanceStats -Results $results
    
    return $results
}

function Show-PerformanceStats {
    param($Results)
    
    $successfulTests = $Results | Where-Object { $_.Success -eq $true }
    
    Write-Host "=== PERFORMANCE SUMMARY ===" -ForegroundColor $Config.Colors.Summary
    Write-Host "Total Tests: $($Results.Count)" -ForegroundColor $Config.Colors.Info
    Write-Host "Successful Tests: $($successfulTests.Count) / $($Results.Count)" -ForegroundColor $Config.Colors.Success
    
    if ($successfulTests.Count -gt 0) {
        $avgResponseTime = ($successfulTests.ResponseTime_MS | Measure-Object -Average).Average
        $minResponseTime = ($successfulTests.ResponseTime_MS | Measure-Object -Minimum).Minimum
        $maxResponseTime = ($successfulTests.ResponseTime_MS | Measure-Object -Maximum).Maximum
        
        Write-Host "Average Response Time: $([math]::Round($avgResponseTime, 2)) ms" -ForegroundColor $Config.Colors.Info
        Write-Host "Minimum Response Time: $minResponseTime ms" -ForegroundColor $Config.Colors.Info
        Write-Host "Maximum Response Time: $maxResponseTime ms" -ForegroundColor $Config.Colors.Info
        Write-Host "Success Rate: $([math]::Round(($successfulTests.Count / $Results.Count) * 100, 2))%" -ForegroundColor $Config.Colors.Info
        
        # Performance categorization
        if ($avgResponseTime -lt 100) {
            Write-Host "Performance Rating: Excellent (< 100ms)" -ForegroundColor $Config.Colors.Success
        }
        elseif ($avgResponseTime -lt 300) {
            Write-Host "Performance Rating: Good (100-300ms)" -ForegroundColor $Config.Colors.Info
        }
        elseif ($avgResponseTime -lt 1000) {
            Write-Host "Performance Rating: Fair (300ms-1s)" -ForegroundColor $Config.Colors.Warning
        }
        else {
            Write-Host "Performance Rating: Poor (> 1s)" -ForegroundColor $Config.Colors.Error
        }
    }
    else {
        Write-Host "No successful tests completed!" -ForegroundColor $Config.Colors.Error
    }
    Write-Host ""
}

# ===== MAIN EXECUTION =====

if ($ContinuousMode) {
    $results = Monitor-APILoading
}
else {
    $results = Measure-APILoading
}

# Store results in global variable for further analysis if needed
$global:LastTestResults = $results