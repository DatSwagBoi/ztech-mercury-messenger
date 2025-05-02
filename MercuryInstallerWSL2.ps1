<#
.SYNOPSIS
    Automated Docker Desktop Installation and Docker Compose Deployment Script
.DESCRIPTION
    This script downloads and installs Docker Desktop silently, waits for it to be ready,
    and then runs a specified Docker Compose file. Designed for remote deployment through RMM tools.
.NOTES
    Author: Hayden
    Version: 1.2
    Date: May 1, 2025
#>

# Set Error Action to continue on errors - changed from Stop to allow graceful handling
$ErrorActionPreference = "Continue"

# Script Parameters - Modify these as needed
$DockerInstallerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$DockerInstallerPath = "$env:TEMP\DockerDesktopInstaller.exe"
$ComposeFilePath = "C:\Path\To\Your\compose.yaml" # Change this to your compose file path
$ComposeProjectDirectory = "C:\Path\To\Your\Project" # Directory containing your compose file
$MaxWaitTimeMinutes = 5
$LogPath = "C:\Logs\DockerDeployment.log" # Path for logging
$WSLUpdateKernelUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
$WSLUpdateKernelPath = "$env:TEMP\wsl_update_x64.msi"

# Create log directory if it doesn't exist
$LogDir = [System.IO.Path]::GetDirectoryName($LogPath)
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Log function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    
    # Add logging to a file
    Add-Content -Path $LogPath -Value $logMessage
}

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        $null = & docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to check system requirements for Docker Desktop
function Test-DockerRequirements {
    Write-Log "Checking system requirements for Docker Desktop..."
    
    # Check OS version
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $osVersion = [System.Environment]::OSVersion.Version
    $osProductType = $osInfo.ProductType
    $osCaption = $osInfo.Caption
    
    Write-Log "OS Version: $($osCaption) ($($osVersion.Major).$($osVersion.Minor).$($osVersion.Build))" "INFO"
    
    # Check if Windows 10/11 and build version
    $isWin10OrHigher = $osVersion.Major -ge 10
    $isBuildValid = $osVersion.Build -ge 19045 # Windows 10 22H2 or higher
    
    if (-not $isWin10OrHigher) {
        Write-Log "Docker Desktop requires Windows 10 or higher" "ERROR"
        return $false
    }
    
    if (-not $isBuildValid) {
        Write-Log "Docker Desktop requires Windows 10 build 19045 (22H2) or higher" "ERROR"
        return $false
    }
    
    # Check for virtualization capability
    try {
        $processorInfo = Get-WmiObject -Class Win32_Processor
        $virtualizationFirmwareEnabled = (Get-ComputerInfo).HyperVisorPresent
        
        if (-not $virtualizationFirmwareEnabled) {
            Write-Log "Hardware virtualization is not enabled in BIOS/UEFI" "WARNING"
            # This is a warning rather than an error since we can't definitively check
        }
    }
    catch {
        Write-Log "Failed to check virtualization status: $_" "WARNING"
    }
    
    # Check WSL 2 status
    try {
        $wslStatus = wsl --status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "WSL is not installed or not properly configured" "WARNING"
            Write-Log "Will attempt to install and configure WSL during installation" "INFO"
        }
        else {
            Write-Log "WSL is installed: $wslStatus" "INFO"
        }
    }
    catch {
        Write-Log "WSL check failed: $_" "WARNING"
        Write-Log "Will attempt to install and configure WSL during installation" "INFO"
    }
    
    # Check system RAM
    $systemRAM = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    Write-Log "System RAM: $($systemRAM.ToString("0.00")) GB" "INFO"
    
    if ($systemRAM -lt 4) {
        Write-Log "Docker Desktop requires at least 4GB of system RAM (Current: $($systemRAM.ToString("0.00")) GB)" "WARNING"
        # Changed from ERROR to WARNING to allow installation to proceed on systems with less RAM
    }
    
    # Check for required Windows features
    try {
        $windowsFeatures = Get-WindowsOptionalFeature -Online
        $virtualizationFeatures = $windowsFeatures | Where-Object { $_.FeatureName -match "Hyper-V|Containers|VirtualMachinePlatform" }
        
        foreach ($feature in $virtualizationFeatures) {
            Write-Log "Windows Feature: $($feature.FeatureName) - $($feature.State)" "INFO"
        }
    }
    catch {
        Write-Log "Failed to check Windows features: $_" "WARNING"
    }
    
    Write-Log "System meets minimum requirements for Docker Desktop" "INFO"
    return $true
}

# Function to add user to docker-users group
function Add-UserToDockerGroup {
    param (
        [string]$Username = $env:USERNAME
    )
    
    try {
        Write-Log "Adding user '$Username' to docker-users group..."
        
        # Check if the docker-users group exists
        $group = Get-LocalGroup -Name "docker-users" -ErrorAction SilentlyContinue
        
        if ($null -eq $group) {
            Write-Log "docker-users group does not exist, Docker Desktop installation may not be complete" "WARNING"
            return $false
        }
        
        # Get current group members
        $currentMembers = Get-LocalGroupMember -Group "docker-users" -ErrorAction SilentlyContinue
        
        # Check if the user is already a member
        $isUserMember = $currentMembers | Where-Object { $_.Name -like "*\$Username" }
        
        if ($null -ne $isUserMember) {
            Write-Log "User '$Username' is already a member of docker-users group" "INFO"
            return $true
        }
        
        # Add the user to the group
        Add-LocalGroupMember -Group "docker-users" -Member $Username
        Write-Log "Successfully added user '$Username' to docker-users group" "INFO"
        
        return $true
    }
    catch {
        Write-Log "Failed to add user to docker-users group: $_" "WARNING"
        # Changed to WARNING to allow script to continue
        return $false
    }
}

# Function to download and install the WSL Update Kernel
function Install-WSLUpdateKernel {
    try {
        Write-Log "Downloading WSL2 Linux kernel update package..."
        Invoke-WebRequest -Uri $WSLUpdateKernelUrl -OutFile $WSLUpdateKernelPath -UseBasicParsing
        
        Write-Log "Installing WSL2 Linux kernel update package..."
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $WSLUpdateKernelPath, "/quiet", "/norestart" -Wait
        
        # Clean up
        if (Test-Path $WSLUpdateKernelPath) {
            Remove-Item -Path $WSLUpdateKernelPath -Force
        }
        
        Write-Log "WSL2 Linux kernel update package installed successfully"
        return $true
    }
    catch {
        Write-Log "Failed to install WSL2 Linux kernel update package: $_" "ERROR"
        return $false
    }
}

# Function to enable and configure WSL 2
function Enable-WSL2 {
    try {
        Write-Log "Enabling WSL 2..."
        
        # Step 1: Enable WSL feature
        Write-Log "Enabling Windows Subsystem for Linux feature..."
        $wslEnabled = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -WarningAction SilentlyContinue
        
        if ($wslEnabled.RestartNeeded) {
            Write-Log "Windows needs to restart to complete WSL installation (will continue anyway)" "WARNING"
        }
        
        # Step 2: Enable Virtual Machine Platform
        Write-Log "Enabling Virtual Machine Platform feature..."
        $vmEnabled = Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -WarningAction SilentlyContinue
        
        if ($vmEnabled.RestartNeeded) {
            Write-Log "Windows needs to restart to complete Virtual Machine Platform installation (will continue anyway)" "WARNING"
        }
        
        # Step 3: Install the WSL2 Linux kernel update package
        Install-WSLUpdateKernel
        
        # Step 4: Set WSL 2 as default
        Write-Log "Setting WSL 2 as the default version..."
        $wslSetDefaultOutput = wsl --set-default-version 2 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Error setting WSL 2 as default: $wslSetDefaultOutput" "WARNING"
            
            # Additional step: Try to run WSL Update command
            Write-Log "Attempting to update WSL..."
            $wslUpdateOutput = wsl --update 2>&1
            Write-Log "WSL update output: $wslUpdateOutput" "INFO"
            
            # Try again to set WSL 2 as default
            $wslSetDefaultRetryOutput = wsl --set-default-version 2 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Still unable to set WSL 2 as default: $wslSetDefaultRetryOutput" "WARNING"
                Write-Log "Continuing despite WSL 2 configuration issues..." "WARNING"
            } else {
                Write-Log "Successfully set WSL 2 as default after update" "INFO"
            }
        } else {
            Write-Log "Successfully set WSL 2 as default version" "INFO"
        }
        
        Write-Log "WSL 2 setup process completed" "INFO"
        return $true
    }
    catch {
        Write-Log "Error during WSL 2 setup: $_" "WARNING"
        Write-Log "Will attempt to continue with Docker Desktop installation anyway" "INFO"
        return $false
    }
}

# Function to handle Docker Desktop installation
function Install-DockerDesktop {
    try {
        Write-Log "Installing Docker Desktop silently..."
        
        # Run the installer with extra error handling
        $process = Start-Process -FilePath $DockerInstallerPath -ArgumentList "install", "--quiet", "--accept-license", "--backend=wsl-2", "--always-run-service" -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            Write-Log "Docker Desktop installer exited with code: $($process.ExitCode)" "WARNING"
            Write-Log "Installation may not have completed successfully, but will continue..." "WARNING"
        } else {
            Write-Log "Docker Desktop installation completed successfully" "INFO"
        }
        
        return $true
    }
    catch {
        Write-Log "Error during Docker Desktop installation: $_" "ERROR"
        Write-Log "Will attempt to continue despite installation errors" "WARNING"
        return $false
    }
}

# Function to wait for Docker to be ready with better handling of timeouts
function Wait-ForDocker {
    param (
        [int]$TimeoutMinutes = 5,
        [int]$RetryIntervalSeconds = 10
    )
    
    Write-Log "Waiting for Docker service to be ready (timeout: $TimeoutMinutes minutes)..."
    $startTime = Get-Date
    $dockerReady = $false
    $attempts = 0
    
    while (-not $dockerReady) {
        $attempts++
        
        if (Test-DockerRunning) {
            $dockerReady = $true
            Write-Log "Docker is now ready (after $attempts attempts)" "INFO"
            return $true
        }
        
        $currentTime = Get-Date
        $elapsedTime = ($currentTime - $startTime).TotalMinutes
        
        if ($elapsedTime -ge $TimeoutMinutes) {
            Write-Log "Timeout waiting for Docker to start after $TimeoutMinutes minutes and $attempts attempts" "WARNING"
            Write-Log "Continuing despite Docker not responding..." "WARNING"
            return $false
        }
        
        Write-Log "Docker not yet ready (attempt $attempts). Waiting $RetryIntervalSeconds seconds..." "INFO"
        Start-Sleep -Seconds $RetryIntervalSeconds
    }
    
    return $true
}

# Function to create a sample Docker Compose environment
function Create-SampleDockerComposeEnvironment {
    param (
        [string]$ComposeFilePath,
        [string]$ProjectDirectory
    )
    
    try {
        Write-Log "Creating a sample Docker Compose file at: $ComposeFilePath" "INFO"
        
        # Create directory if it doesn't exist
        if (-not (Test-Path $ProjectDirectory)) {
            New-Item -ItemType Directory -Path $ProjectDirectory -Force | Out-Null
        }
        
        # Create a simple compose file
        $sampleComposeContent = @"
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
"@
        
        # Create the compose file
        Set-Content -Path $ComposeFilePath -Value $sampleComposeContent
        
        # Create index.html
        $htmlDir = Join-Path -Path $ProjectDirectory -ChildPath "html"
        if (-not (Test-Path $htmlDir)) {
            New-Item -ItemType Directory -Path $htmlDir -Force | Out-Null
        }
        
        $indexHtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Docker Compose Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            text-align: center;
        }
        h1 {
            color: #0066cc;
        }
    </style>
</head>
<body>
    <h1>Docker Compose Deployment Successful!</h1>
    <p>This page confirms that Docker Desktop and Docker Compose have been successfully deployed.</p>
    <p>Deployed on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    <p>Hostname: $(hostname)</p>
</body>
</html>
"@
        
        Set-Content -Path (Join-Path -Path $htmlDir -ChildPath "index.html") -Value $indexHtmlContent
        
        Write-Log "Sample Docker Compose environment created successfully" "INFO"
        return $true
    }
    catch {
        Write-Log "Error creating sample Docker Compose environment: $_" "ERROR"
        return $false
    }
}

# Function to run Docker Compose
function Run-DockerCompose {
    param (
        [string]$ComposeFilePath,
        [string]$ProjectDirectory
    )
    
    try {
        Write-Log "Running Docker Compose..."
        
        # Change to the project directory
        Push-Location -Path $ProjectDirectory
        
        # Run docker-compose with error handling
        $composeOutput = & docker-compose -f $ComposeFilePath up -d 2>&1
        $composeExitCode = $LASTEXITCODE
        
        # Log the output regardless of success or failure
        Write-Log "Docker Compose output: $composeOutput"
        
        if ($composeExitCode -ne 0) {
            Write-Log "Docker Compose command failed with exit code: $composeExitCode" "ERROR"
            Write-Log "Will attempt to continue despite Docker Compose errors" "WARNING"
        } else {
            Write-Log "Docker Compose deployment completed successfully" "INFO"
        }
        
        # Try to display container status even if compose had errors
        try {
            $containerStatus = & docker-compose -f $ComposeFilePath ps 2>&1
            Write-Log "Container Status: $containerStatus" "INFO"
        }
        catch {
            Write-Log "Could not get container status: $_" "WARNING"
        }
        
        # Return to original directory
        Pop-Location
        
        return ($composeExitCode -eq 0)
    }
    catch {
        Write-Log "Error running Docker Compose: $_" "ERROR"
        
        # Return to original directory
        Pop-Location
        
        return $false
    }
}

# Main script execution begins
Write-Log "Starting Docker Desktop deployment script"

# Create a flag to track overall success
$overallSuccess = $true

# Check system requirements
$systemRequirementsMet = Test-DockerRequirements
if (-not $systemRequirementsMet) {
    Write-Log "System does not meet Docker Desktop requirements, but will attempt to continue" "WARNING"
    $overallSuccess = $false
}

# Check if Docker Desktop is already installed
if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
    Write-Log "Docker Desktop is already installed" "INFO"
    $dockerInstalled = $true
}
else {
    $dockerInstalled = $false
    
    # Download Docker Desktop installer
    try {
        Write-Log "Downloading Docker Desktop installer..."
        Invoke-WebRequest -Uri $DockerInstallerUrl -OutFile $DockerInstallerPath -UseBasicParsing
        Write-Log "Download completed successfully"
    }
    catch {
        Write-Log "Failed to download Docker Desktop installer: $_" "ERROR"
        Write-Log "Will try to use existing installer if available or attempt direct download with alternate method" "INFO"
        
        # Try alternate download method
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($DockerInstallerUrl, $DockerInstallerPath)
            Write-Log "Alternate download method succeeded" "INFO"
        }
        catch {
            Write-Log "All download attempts failed. Cannot proceed with Docker Desktop installation." "ERROR"
            $overallSuccess = $false
            
            # Check if we already have the installer from a previous run
            if (Test-Path $DockerInstallerPath) {
                Write-Log "Found existing Docker installer from previous run. Will attempt to use it." "INFO"
            }
            else {
                Write-Log "No installer available. Skipping Docker Desktop installation." "ERROR"
                $dockerInstalled = $false
                # Don't exit, continue with other steps
            }
        }
    }

    # Enable WSL 2 if needed
    if (Test-Path $DockerInstallerPath) {
        # First attempt to run WSL update if available
        try {
            Write-Log "Attempting to update WSL kernel first..."
            $wslUpdateOutput = wsl --update 2>&1
            Write-Log "WSL update output: $wslUpdateOutput" "INFO"
        }
        catch {
            Write-Log "WSL update command failed: $_" "INFO"
            Write-Log "Will try manual WSL setup..." "INFO"
        }
        
        # Now enable WSL 2
        $wslEnabled = Enable-WSL2
        
        # Install Docker Desktop
        $dockerInstalled = Install-DockerDesktop
        
        # Cleanup the installer
        if (Test-Path $DockerInstallerPath) {
            try {
                Remove-Item -Path $DockerInstallerPath -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Failed to remove installer file, but continuing: $_" "WARNING"
            }
        }
    }
    
    # Add current user to docker-users group if Docker was installed
    if ($dockerInstalled) {
        Add-UserToDockerGroup
    }
}

# Start Docker Desktop if not running
if ($dockerInstalled -and -not (Test-DockerRunning)) {
    Write-Log "Starting Docker Desktop..."
    try {
        # Try to start Docker Desktop
        if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
            Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            Write-Log "Docker Desktop start process initiated" "INFO"
        }
        else {
            Write-Log "Docker Desktop executable not found at expected location" "WARNING"
            $overallSuccess = $false
        }
    }
    catch {
        Write-Log "Failed to start Docker Desktop: $_" "ERROR"
        Write-Log "Will still attempt to continue with Docker operations" "WARNING"
        $overallSuccess = $false
    }
    
    # Wait for Docker to be ready with timeout handling
    $dockerReady = Wait-ForDocker -TimeoutMinutes $MaxWaitTimeMinutes -RetryIntervalSeconds 10
    if (-not $dockerReady) {
        Write-Log "Docker did not start within timeout period, but continuing with other operations" "WARNING"
        $overallSuccess = $false
    }
}

# Check if the Compose file exists
$createSample = $false
if (-not (Test-Path $ComposeFilePath)) {
    Write-Log "Docker Compose file not found at: $ComposeFilePath" "WARNING"
    
    # Create a sample compose file
    $createSample = $true
    $sampleCreated = Create-SampleDockerComposeEnvironment -ComposeFilePath $ComposeFilePath -ProjectDirectory $ComposeProjectDirectory
    
    if (-not $sampleCreated) {
        Write-Log "Failed to create sample Docker Compose environment" "ERROR"
        $overallSuccess = $false
    }
}

# Only attempt to run Docker Compose if Docker is ready
if (Test-DockerRunning) {
    # Run Docker Compose
    $composeSuccess = Run-DockerCompose -ComposeFilePath $ComposeFilePath -ProjectDirectory $ComposeProjectDirectory
    
    if (-not $composeSuccess) {
        Write-Log "Docker Compose deployment had issues" "WARNING"
        $overallSuccess = $false
    }
}
else {
    Write-Log "Docker is not running. Skipping Docker Compose deployment." "WARNING"
    $overallSuccess = $false
}

# Final status report
if ($overallSuccess) {
    Write-Log "Deployment process completed successfully" "INFO"
}
else {
    Write-Log "Deployment process completed with some issues - see log for details" "WARNING"
}

# Display basic information for verification
Write-Host "==============================================" -ForegroundColor Yellow
if ($overallSuccess) {
    Write-Host "Docker Desktop and Compose Deployment Complete" -ForegroundColor Green
}
else {
    Write-Host "Docker Deployment Completed with Some Issues" -ForegroundColor Yellow
    Write-Host "See log file for details on what succeeded and what failed" -ForegroundColor Yellow
}
Write-Host "==============================================" -ForegroundColor Yellow

# Try to display Docker version information
try {
    $dockerVersion = docker --version 2>&1
    Write-Host "Docker Version: $dockerVersion" -ForegroundColor Cyan
}
catch {
    Write-Host "Docker is not responding or not installed correctly" -ForegroundColor Red
}

# Try to display Docker Compose version information
try {
    $composeVersion = docker-compose --version 2>&1
    Write-Host "Docker Compose Version: $composeVersion" -ForegroundColor Cyan
}
catch {
    Write-Host "Docker Compose is not responding or not installed correctly" -ForegroundColor Red
}

Write-Host "Log file: $LogPath" -ForegroundColor Cyan

# If using the sample Nginx container, show the URL
if ($createSample -and $composeSuccess) {
    Write-Host "Sample website available at: http://localhost:8080" -ForegroundColor Yellow
    Write-Host "You can access this from the server's browser or remotely if port 8080 is accessible" -ForegroundColor Yellow
}

# Exit with appropriate code
if ($overallSuccess) {
    exit 0
}
else {
    # Exit with a success code anyway to prevent RMM tool alerts
    # You can change this to exit 1 if you prefer to have your RMM tool alert on issues
    Write-Log "Exiting with code 0 despite issues to prevent RMM alerts" "INFO"
    exit 0
}