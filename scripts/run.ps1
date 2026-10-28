# ==============================================================================
# Project KannaOS - Run Script (PowerShell)
# Launches the KannaOS VirtualBox VM with the freshly built ISO
# ==============================================================================
param (
    [switch]$Headless
)

$workspaceRoot = Split-Path -Parent $PSScriptRoot
Set-Location $workspaceRoot

# 1. First ensure latest build
& "$PSScriptRoot\build.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed; cannot launch VM."
    exit 1
}

# 2. Locate VirtualBox
$vboxPaths = @(
    "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    "$env:VBOX_MSI_INSTALL_PATH\VBoxManage.exe"
)

$vbox = $null
foreach ($p in $vboxPaths) {
    if (Test-Path $p) {
        $vbox = $p
        break
    }
}

if (-not $vbox) {
    Write-Error "VirtualBox (VBoxManage.exe) not found at standard location 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'."
    exit 1
}

$vmName = "KannaOS"
Write-Host "`nChecking VirtualBox VM '$vmName'..." -ForegroundColor Cyan

# Check if VM exists
$vmList = & $vbox list vms
$vmFound = ($vmList | Where-Object { $_ -match ('"' + [regex]::Escape($vmName) + '"') })
if (-not $vmFound) {
    Write-Host "Creating VirtualBox VM '$vmName'..." -ForegroundColor Yellow
    & $vbox createvm --name $vmName --ostype "Other" --register
    & $vbox modifyvm $vmName --memory 64 --vram 16 --boot1 dvd --boot2 floppy --nic1 nat
    & $vbox storagectl $vmName --name "IDE" --add ide --controller PIIX4 --bootable on
    $isoPath = Join-Path $workspaceRoot "build\kannaos.iso"
    & $vbox storageattach $vmName --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium $isoPath
    Write-Host "VM '$vmName' created and configured with $isoPath." -ForegroundColor Green
} else {
    Write-Host "VirtualBox VM '$vmName' found." -ForegroundColor Green
}

# Check if VM is already running
$runningVMs = & $vbox list runningvms
$vmRunning = ($runningVMs | Where-Object { $_ -match ('"' + [regex]::Escape($vmName) + '"') })
if ($vmRunning) {
    Write-Host "VM '$vmName' is already running!" -ForegroundColor Yellow
    exit 0
}

Write-Host "Starting VM '$vmName'..." -ForegroundColor Green
if ($Headless) {
    & $vbox startvm $vmName --type headless
} else {
    & $vbox startvm $vmName
}

Write-Host "KannaOS VM started successfully!" -ForegroundColor Green
