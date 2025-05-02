<#
.SYNOPSIS
    ZTech Mercury Messenger Deployment Script with Hyper-V
.DESCRIPTION
    This script downloads the ZTech Mercury Messenger GitHub repository if needed,
    installs Docker Desktop silently using Hyper-V backend instead of WSL, and deploys the application.
    It's designed for deployment through ConnectWise Control RMM.
.NOTES
    Author: Hayden
    Version: 1.2
    Date: May 1, 2025
#>

# Set Error Action to stop on errors
$ErrorActionPreference = "Stop"

# Script Parameters - Modify these as needed
$DockerInstallerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$DockerInstallerPath = "$env:TEMP\DockerDesktopInstaller.exe"
$GitHubRepoUrl = "https://github.com/DatSwagBoi/ztech-mercury-messenger" # Update with actual GitHub repo URL
$InstallPath = "C:\ZTech\ztech-mercury-messenger" # Target installation directory
$ZipDownloadPath = "$env:TEMP\ztech-mercury-messenger.zip"
$ExtractPath = "$env:TEMP\ztech-mercury-extract"
$LogPath = "C:\ZTech\Logs\MercuryDeployment.log"
$MaxWaitTimeMinutes = 10

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

# Function to find the repository location
function Find-Repository {
    Write-Log "Searching for ZTech Mercury Messenger repository..."
    
    # Check common locations
    $possibleLocations = @(
        "$env:USERPROFILE\Downloads\ztech-mercury-messenger-main",
        "$env:USERPROFILE\Downloads\ztech-mercury-messenger-main\ztech-mercury-messenger-main",
        "$env:USERPROFILE\ztech-mercury-messenger-main\ztech-mercury-messenger-main",
        "$env:USERPROFILE\Desktop\ztech-mercury-messenger-main",
        "$env:USERPROFILE\Documents\ztech-mercury-messenger-main"
    )
    
    foreach ($location in $possibleLocations) {
        if (Test-Path $location) {
            # Verify it's the right repository by checking for key files
            if ((Test-Path "$location\docker-compose.yml") -and (Test-Path "$location\Dockerfile")) {
                Write-Log "Found repository at: $location"
                return $location
            }
        }
    }
    
    Write-Log "Repository not found in common locations" "WARNING"
    return $null
}

# Function to download and extract the repository
function Get-Repository {
    # First, try to find existing repository
    $repoPath = Find-Repository
    if ($repoPath) {
        return $repoPath
    }
    
    # If not found, download from GitHub
    Write-Log "Downloading ZTech Mercury Messenger repository from GitHub..."
    
    try {
        # Create temp directory for extraction
        if (Test-Path $ExtractPath) {
            Remove-Item -Path $ExtractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
        
        # Download the zip file
        Invoke-WebRequest -Uri $GitHubRepoUrl -OutFile $ZipDownloadPath
        Write-Log "Download completed successfully"
        
        # Extract the zip file
        Write-Log "Extracting repository..."
        Expand-Archive -Path $ZipDownloadPath -DestinationPath $ExtractPath -Force
        
        # Find the repository root (usually one directory inside the zip)
        $extractedDirs = Get-ChildItem -Path $ExtractPath -Directory
        
        if ($extractedDirs.Count -eq 0) {
            Write-Log "No directories found in extracted archive" "ERROR"
            return $null
        }
        
        $mainDir = $extractedDirs[0].FullName
        
        # Check if there's another level of nesting
        $nestedDir = Join-Path -Path $mainDir -ChildPath "ztech-mercury-messenger-main"
        if (Test-Path $nestedDir) {
            $mainDir = $nestedDir
        }
        
        # Verify it's the right repository
        if ((Test-Path "$mainDir\docker-compose.yml") -and (Test-Path "$mainDir\Dockerfile")) {
            Write-Log "Repository extracted successfully to: $mainDir"
            return $mainDir
        } else {
            Write-Log "Downloaded files do not contain the expected repository structure" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Failed to download or extract repository: $_" "ERROR"
        return $null
    }
    finally {
        # Clean up the zip file
        if (Test-Path $ZipDownloadPath) {
            Remove-Item -Path $ZipDownloadPath -Force
        }
    }
}

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        $null = & docker info
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to check system requirements for Docker Desktop with Hyper-V
function Test-DockerRequirements {
    Write-Log "Checking system requirements for Docker Desktop with Hyper-V..."
    
    # Check OS version and edition
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $osVersion = [System.Environment]::OSVersion.Version
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
    
    # Check if Pro, Enterprise, or Education edition (required for Hyper-V)
    $isValidEdition = $osCaption -match "Pro|Enterprise|Education"
    if (-not $isValidEdition) {
        Write-Log "Hyper-V requires Windows 10/11 Pro, Enterprise, or Education edition" "ERROR"
        return $false
    }
    
    # Check for virtualization capability
    try {
        $virtualizationFirmwareEnabled = (Get-ComputerInfo).HyperVisorPresent
        
        if (-not $virtualizationFirmwareEnabled) {
            Write-Log "Hardware virtualization is not enabled in BIOS/UEFI" "WARNING"
        }
    }
    catch {
        Write-Log "Failed to check virtualization status: $_" "WARNING"
    }
    
    # Check system RAM
    $systemRAM = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    Write-Log "System RAM: $($systemRAM.ToString("0.00")) GB" "INFO"
    
    if ($systemRAM -lt 4) {
        Write-Log "Docker Desktop requires at least 4GB of system RAM (Current: $($systemRAM.ToString("0.00")) GB)" "ERROR"
        return $false
    }
    
    # Check Hyper-V status
    try {
        $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
        
        if ($hyperVFeature.State -ne "Enabled") {
            Write-Log "Hyper-V is not enabled. It will be enabled during installation." "INFO"
        } else {
            Write-Log "Hyper-V is already enabled" "INFO"
        }
    }
    catch {
        Write-Log "Failed to check Hyper-V status: $_" "WARNING"
    }
    
    Write-Log "System meets minimum requirements for Docker Desktop with Hyper-V" "INFO"
    return $true
}

# Function to enable Hyper-V
function Enable-HyperV {
    try {
        Write-Log "Enabling Hyper-V and Containers features..."
        
        # Enable Hyper-V feature
        $hyperVEnabled = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
        
        if ($hyperVEnabled.RestartNeeded) {
            Write-Log "Windows needs to restart to complete Hyper-V installation" "WARNING"
        }
        
        # Enable Containers feature
        $containersEnabled = Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
        
        if ($containersEnabled.RestartNeeded) {
            Write-Log "Windows needs to restart to complete Containers feature installation" "WARNING"
        }
        
        Write-Log "Hyper-V and Containers features have been enabled" "INFO"
        
        # Check if restart is needed
        if ($hyperVEnabled.RestartNeeded -or $containersEnabled.RestartNeeded) {
            Write-Log "A system restart is required to complete the installation of Hyper-V and Containers" "WARNING"
            
            $restartChoice = Read-Host "Do you want to restart the computer now? (Y/N)"
            if ($restartChoice -eq "Y" -or $restartChoice -eq "y") {
                Write-Log "Restarting computer..."
                Restart-Computer -Force
                exit 0
            } else {
                Write-Log "Please restart your computer manually to complete the Docker Desktop installation" "WARNING"
                Write-Log "After restarting, run this script again to complete the deployment" "WARNING"
                exit 0
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to enable Hyper-V: $_" "ERROR"
        return $false
    }
}

# Function to deploy the project files
function Deploy-Project {
    param (
        [string]$SourcePath
    )
    
    try {
        Write-Log "Deploying ZTech Mercury Messenger to $InstallPath..."
        
        # Create install directory if it doesn't exist
        if (-not (Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
            Write-Log "Created installation directory: $InstallPath"
        }
        
        # Use robocopy to copy all files and folders (excluding data and ollama-data)
        $robocopyArgs = @(
            $SourcePath,
            $InstallPath,
            "/E",          # Copy subdirectories, including empty ones
            "/COPY:DAT",   # Copy data, attributes, and timestamps
            "/XD",         # Exclude directories
            "data",
            "ollama-data"
        )
        
        & robocopy $robocopyArgs
        
        # Create required directories
        $dataDir = Join-Path -Path $InstallPath -ChildPath "data"
        $ollamaDir = Join-Path -Path $InstallPath -ChildPath "ollama-data"
        
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
            Write-Log "Created data directory: $dataDir"
        }
        
        if (-not (Test-Path $ollamaDir)) {
            New-Item -ItemType Directory -Path $ollamaDir -Force | Out-Null
            Write-Log "Created ollama-data directory: $ollamaDir"
        }
        
        # Create .env file if it doesn't exist
        $envFile = Join-Path -Path $InstallPath -ChildPath ".env"
        if (-not (Test-Path $envFile)) {
            $envContent = @"
# ZTech Mercury Messenger Environment Configuration
JWT_SECRET=$(New-Guid)
"@
            Set-Content -Path $envFile -Value $envContent
            Write-Log "Created .env file with secure JWT secret"
        }
        
        Write-Log "Project deployed successfully to $InstallPath"
        return $true
    }
    catch {
        Write-Log "Failed to deploy project: $_" "ERROR"
        return $false
    }
}

# Main script execution begins
Write-Log "Starting ZTech Mercury Messenger deployment script"

# Step 1: Get the repository (find existing or download from GitHub)
$sourcePath = Get-Repository
if (-not $sourcePath) {
    Write-Log "Failed to locate or download the ZTech Mercury Messenger repository. Exiting." "ERROR"
    exit 1
}

# Step 2: Check system requirements for Hyper-V
$systemRequirementsMet = Test-DockerRequirements
if (-not $systemRequirementsMet) {
    Write-Log "System does not meet Docker Desktop requirements with Hyper-V. Exiting." "ERROR"
    exit 1
}

# Step 3: Enable Hyper-V if needed
Enable-HyperV

# Step 4: Install Docker Desktop if needed
if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
    Write-Log "Docker Desktop is already installed" "INFO"
}
else {
    # Download Docker Desktop installer
    Write-Log "Downloading Docker Desktop installer..."
    try {
        Invoke-WebRequest -Uri $DockerInstallerUrl -OutFile $DockerInstallerPath
        Write-Log "Download completed successfully"
    }
    catch {
        Write-Log "Failed to download Docker Desktop installer: $_" "ERROR"
        exit 1
    }

    # Install Docker Desktop silently with Hyper-V backend
    Write-Log "Installing Docker Desktop silently with Hyper-V backend..."
    try {
        Start-Process -FilePath $DockerInstallerPath -ArgumentList "install", "--quiet", "--accept-license", "--backend=hyper-v", "--always-run-service" -Wait
        Write-Log "Installation completed successfully"
    }
    catch {
        Write-Log "Failed to install Docker Desktop: $_" "ERROR"
        exit 1
    }
    finally {
        # Cleanup the installer
        if (Test-Path $DockerInstallerPath) {
            Remove-Item -Path $DockerInstallerPath -Force
        }
    }
}

# Step 5: Start Docker Desktop if not running
if (-not (Test-DockerRunning)) {
    Write-Log "Starting Docker Desktop..."
    try {
        Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    }
    catch {
        Write-Log "Failed to start Docker Desktop: $_" "ERROR"
        exit 1
    }
}

# Step 6: Wait for Docker to be ready
Write-Log "Waiting for Docker service to be ready..."
$startTime = Get-Date
$dockerReady = $false

while (-not $dockerReady) {
    if (Test-DockerRunning) {
        $dockerReady = $true
        Write-Log "Docker is now ready"
    }
    else {
        $currentTime = Get-Date
        $elapsedTime = ($currentTime - $startTime).TotalMinutes
        
        if ($elapsedTime -ge $MaxWaitTimeMinutes) {
            Write-Log "Timeout waiting for Docker to start after $MaxWaitTimeMinutes minutes" "ERROR"
            exit 1
        }
        
        Write-Log "Docker not yet ready. Waiting 10 seconds..." "INFO"
        Start-Sleep -Seconds 10
    }
}

# Step 7: Deploy the project files
$deploymentSuccessful = Deploy-Project -SourcePath $sourcePath
if (-not $deploymentSuccessful) {
    Write-Log "Failed to deploy the project. Exiting." "ERROR"
    exit 1
}

# Step 8: Deploy with Docker Compose
Write-Log "Deploying ZTech Mercury Messenger with Docker Compose..."
try {
    Set-Location -Path $InstallPath
    
    # Pull required Docker images first
    Write-Log "Pulling required Docker images..."
    & docker-compose pull
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to pull Docker images with exit code: $LASTEXITCODE" "WARNING"
        # Continue anyway - images might be pulled during compose up
    }
    
    # Run docker-compose
    Write-Log "Starting the application with docker-compose..."
    & docker-compose up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Docker Compose command failed with exit code: $LASTEXITCODE" "ERROR"
        exit 1
    }
    
    Write-Log "Docker Compose deployment completed successfully"
    
    # Display container status
    $containerStatus = & docker-compose ps
    Write-Log "Container Status: $containerStatus" "INFO"
    
    # Check if containers are running correctly
    $runningContainers = & docker ps --filter "name=ztech-mercury" --format "{{.Names}}"
    if (-not $runningContainers) {
        Write-Log "No ZTech Mercury containers found running. Deployment may have failed." "WARNING"
    }
    else {
        Write-Log "ZTech Mercury containers are running: $runningContainers" "INFO"
    }
}
catch {
    Write-Log "Error deploying ZTech Mercury Messenger: $_" "ERROR"
    exit 1
}

# Step 9: Create shortcut on desktop
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\ZTech Mercury Messenger.lnk")
    $Shortcut.TargetPath = "http://localhost:3001"
    $Shortcut.IconLocation = "C:\Program Files\Docker\Docker\Docker Desktop.exe,0"
    $Shortcut.Description = "ZTech Mercury Messenger - Enterprise Messaging Platform"
    $Shortcut.Save()
    Write-Log "Created desktop shortcut for ZTech Mercury Messenger"
}
catch {
    Write-Log "Failed to create desktop shortcut: $_" "WARNING"
}

# Step 10: Clean up temporary files
try {
    if (Test-Path $ExtractPath) {
        Remove-Item -Path $ExtractPath -Recurse -Force
        Write-Log "Cleaned up temporary files"
    }
}
catch {
    Write-Log "Failed to clean up temporary files: $_" "WARNING"
}

Write-Log "Deployment process completed successfully"

# Display success information
Write-Host "==============================================" -ForegroundColor Green
Write-Host "ZTech Mercury Messenger Deployment Complete" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host "Docker Version: $(docker --version)" -ForegroundColor Cyan
Write-Host "Docker Compose Version: $(docker-compose --version)" -ForegroundColor Cyan
Write-Host "Application URL: http://localhost:3001" -ForegroundColor Yellow
Write-Host "Project Location: $InstallPath" -ForegroundColor Cyan
Write-Host "Log file: $LogPath" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White
Write-Host "IMPORTANT: The first startup may take several minutes while" -ForegroundColor Yellow
Write-Host "Ollama downloads the required AI models." -ForegroundColor Yellow
Write-Host "" -ForegroundColor White
Write-Host "For support, contact Z-TECH Associates" -ForegroundColor Cyan

exit 0