# Configuration
$HostsFile = "/home/regi/PS_Tracert/hosts.txt"            # File containing the list of hosts (one per line)
$OutputDir = "/home/regi/PS_Tracert/Results"                      # Directory to store output files
$TracerouteCount = 3                                    # Number of hops for traceroute (optional)

# Ensure the output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# Get the current timestamp for the output file
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = Join-Path -Path $OutputDir -ChildPath "traceroute_results_$Timestamp.txt"

# Check if the hosts file exists
if (-not (Test-Path $HostsFile)) {
    Write-Host "Error: Hosts file '$HostsFile' not found." -ForegroundColor Red
    exit 1
}

# Create a runspace to traceroute each host simultaneously
$jobs = @()

Get-Content $HostsFile | ForEach-Object {
    $CurrentHost = $_.Trim()
    if (-not [string]::IsNullOrWhiteSpace($CurrentHost)) {
        # Start each traceroute in the background as a job with the traceroute logic defined inside the job
        $jobs += Start-Job -ScriptBlock {
            param ($HostToTraceroute, $OutputFilePath, $TracerouteCount)
            
            # Define the Traceroute function inside the job
            function Traceroute-Host {
                param (
                    [string]$TargetHost,
                    [int]$Count
                )
                
                # Perform the traceroute command
                $TracerouteResult = traceroute $TargetHost -m $Count
                
                # Check if traceroute returned results
                if ($TracerouteResult) {
                    Add-Content -Path $OutputFilePath -Value "Tracerouting $TargetHost..."
                    Add-Content -Path $OutputFilePath -Value $TracerouteResult
                } else {
                    Add-Content -Path $OutputFilePath -Value "Traceroute to $TargetHost failed."
                }
                Add-Content -Path $OutputFilePath -Value "`n----- Separator -----`n"
            }
            
            # Call the Traceroute-Host function with the current host
            Traceroute-Host -TargetHost $HostToTraceroute -Count $TracerouteCount
        } -ArgumentList $CurrentHost, $OutputFile, $TracerouteCount
    }
}

# Wait for all jobs to complete and collect results
$jobs | ForEach-Object {
    # Wait for the job to complete and then remove it
    Wait-Job -Job $_
    Receive-Job -Job $_
    Remove-Job -Job $_
}

Write-Host "Traceroute results saved to $OutputFile" -ForegroundColor Green
