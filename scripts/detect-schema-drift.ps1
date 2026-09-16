param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [string]$Database = "HealthcareCICD",

    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

# ============================================================
# SQL Server Schema Drift Detection
#
# Exit Codes:
#
#   0  = No schema drift detected
#   10 = Schema drift detected
#   1  = Technical error
#
# DriftReport detects changes made to the registered database
# since the last successful DAC registration.
# ============================================================

$ProjectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $ProjectRoot "drift-report.xml"
}

Write-Host "========================================"
Write-Host "SQL Server Schema Drift Detection"
Write-Host "========================================"
Write-Host "Server:   $Server"
Write-Host "Database: $Database"
Write-Host "Report:   $OutputPath"
Write-Host ""

# ------------------------------------------------------------
# Verify SqlPackage
# ------------------------------------------------------------

if (-not (Get-Command sqlpackage -ErrorAction SilentlyContinue)) {
    Write-Error "SqlPackage was not found in PATH."
    exit 1
}

Write-Host "SqlPackage found."
Write-Host ""

# ------------------------------------------------------------
# Verify credentials
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($env:SQL_USERNAME)) {
    Write-Error "SQL_USERNAME environment variable is not set."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:SQL_PASSWORD)) {
    Write-Error "SQL_PASSWORD environment variable is not set."
    exit 1
}

Write-Host "SQL credentials are available."
Write-Host ""

# ------------------------------------------------------------
# Remove old report
# ------------------------------------------------------------

if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Force
}

# ------------------------------------------------------------
# Generate DriftReport
# ------------------------------------------------------------

Write-Host "Generating SQL Server DriftReport..."
Write-Host ""

try {
    sqlpackage `
        /Action:DriftReport `
        /TargetServerName:"$Server" `
        /TargetDatabaseName:"$Database" `
        /TargetUser:"$env:SQL_USERNAME" `
        /TargetPassword:"$env:SQL_PASSWORD" `
        /TargetTrustServerCertificate:True `
        /OutputPath:"$OutputPath"

    $SqlPackageExitCode = $LASTEXITCODE
}
catch {
    Write-Error "Failed to execute SqlPackage."
    Write-Error $_.Exception.Message
    exit 1
}

if ($SqlPackageExitCode -ne 0) {
    Write-Error "SqlPackage DriftReport failed."
    exit 1
}

if (-not (Test-Path $OutputPath)) {
    Write-Error "DriftReport was not created."
    exit 1
}

Write-Host ""
Write-Host "DriftReport generated successfully."
Write-Host ""

# ------------------------------------------------------------
# Parse XML
# ------------------------------------------------------------

try {
    [xml]$DriftXml = Get-Content `
        -Path $OutputPath `
        -Raw
}
catch {
    Write-Error "The DriftReport is not valid XML."
    exit 1
}

try {
    $Additions = @(
        $DriftXml.SelectNodes(
            "//*[local-name()='Additions']/*"
        )
    )

    $Removals = @(
        $DriftXml.SelectNodes(
            "//*[local-name()='Removals']/*"
        )
    )

    $RawModifications = @(
        $DriftXml.SelectNodes(
            "//*[local-name()='Modifications']/*"
        )
    )
}
catch {
    Write-Error "Failed to analyze DriftReport XML."
    Write-Error $_.Exception.Message
    exit 1
}

# ------------------------------------------------------------
# Normalize modifications
#
# SqlPackage may report both:
#
#   Addition:
#       [ManualDriftColumn]
#
#   Modification:
#       [Patients]
#
# The table modification is a consequence of the column change.
#
# We do not count a parent table modification when that table
# already has an addition/removal underneath it.
# ------------------------------------------------------------

$Modifications = @()

foreach ($Modification in $RawModifications) {

    $ModificationName = $Modification.GetAttribute("Name")
    $ModificationParent = $Modification.GetAttribute("Parent")

    $IsParentOfAddition = $false
    $IsParentOfRemoval = $false

    foreach ($Addition in $Additions) {

        $AdditionParent = $Addition.GetAttribute("Parent")

        if (
            -not [string]::IsNullOrWhiteSpace($AdditionParent) -and
            $AdditionParent -eq "$ModificationParent.$ModificationName"
        ) {
            $IsParentOfAddition = $true
            break
        }
    }

    foreach ($Removal in $Removals) {

        $RemovalParent = $Removal.GetAttribute("Parent")

        if (
            -not [string]::IsNullOrWhiteSpace($RemovalParent) -and
            $RemovalParent -eq "$ModificationParent.$ModificationName"
        ) {
            $IsParentOfRemoval = $true
            break
        }
    }

    if (-not $IsParentOfAddition -and -not $IsParentOfRemoval) {
        $Modifications += $Modification
    }
}

# ------------------------------------------------------------
# Counts
# ------------------------------------------------------------

$AdditionCount = $Additions.Count
$RemovalCount = $Removals.Count
$ModificationCount = $Modifications.Count

$TotalDrift = `
    $AdditionCount +
    $RemovalCount +
    $ModificationCount

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

Write-Host "Drift report summary:"
Write-Host "  Additions:      $AdditionCount"
Write-Host "  Removals:       $RemovalCount"
Write-Host "  Modifications:  $ModificationCount"
Write-Host ""

# ------------------------------------------------------------
# No drift
# ------------------------------------------------------------

if ($TotalDrift -eq 0) {

    Write-Host "========================================" -ForegroundColor Green
    Write-Host "NO SCHEMA DRIFT DETECTED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "The registered database has not changed"
    Write-Host "since the last successful registration."
    Write-Host ""

    exit 0
}

# ------------------------------------------------------------
# Drift detected
# ------------------------------------------------------------

Write-Host "========================================" -ForegroundColor Red
Write-Host "SCHEMA DRIFT DETECTED" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

# ------------------------------------------------------------
# Additions
# ------------------------------------------------------------

if ($AdditionCount -gt 0) {

    Write-Host "Additions:" -ForegroundColor Yellow

    foreach ($Object in $Additions) {

        $Name = $Object.GetAttribute("Name")
        $Parent = $Object.GetAttribute("Parent")
        $Type = $Object.GetAttribute("Type")

        Write-Host "  + Name:   $Name"
        Write-Host "    Parent: $Parent"
        Write-Host "    Type:   $Type"
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Removals
# ------------------------------------------------------------

if ($RemovalCount -gt 0) {

    Write-Host "Removals:" -ForegroundColor Yellow

    foreach ($Object in $Removals) {

        $Name = $Object.GetAttribute("Name")
        $Parent = $Object.GetAttribute("Parent")
        $Type = $Object.GetAttribute("Type")

        Write-Host "  - Name:   $Name"
        Write-Host "    Parent: $Parent"
        Write-Host "    Type:   $Type"
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Independent modifications
# ------------------------------------------------------------

if ($ModificationCount -gt 0) {

    Write-Host "Modifications:" -ForegroundColor Yellow

    foreach ($Object in $Modifications) {

        $Name = $Object.GetAttribute("Name")
        $Parent = $Object.GetAttribute("Parent")
        $Type = $Object.GetAttribute("Type")

        Write-Host "  ~ Name:   $Name"
        Write-Host "    Parent: $Parent"
        Write-Host "    Type:   $Type"
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Final result
# ------------------------------------------------------------

Write-Host "Drift report:"
Write-Host $OutputPath
Write-Host ""

Write-Host "CI/CD deployment should stop."
Write-Host ""

exit 10