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
# IMPORTANT:
# This script does NOT compare the current Git DACPAC against
# the live database.
#
# It uses SqlPackage DriftReport to detect changes made to the
# registered database since the last successful registration.
#
# This allows intentional Git changes to proceed while still
# detecting manual database changes.
# ============================================================

$ProjectRoot = Split-Path -Parent $PSScriptRoot

# ------------------------------------------------------------
# Default DriftReport path
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($OutputPath)) {

    $OutputPath = Join-Path `
        $ProjectRoot `
        "drift-report.xml"
}

# ------------------------------------------------------------
# Display configuration
# ------------------------------------------------------------

Write-Host "========================================"
Write-Host "SQL Server Schema Drift Detection"
Write-Host "========================================"
Write-Host "Server:   $Server"
Write-Host "Database: $Database"
Write-Host "Report:   $OutputPath"
Write-Host ""

# ------------------------------------------------------------
# Validate SqlPackage
# ------------------------------------------------------------

if (-not (Get-Command sqlpackage -ErrorAction SilentlyContinue)) {

    Write-Error "SqlPackage was not found in PATH."
    exit 1
}

Write-Host "SqlPackage found."
Write-Host ""

# ------------------------------------------------------------
# Validate credentials
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

sqlpackage `
    /Action:DriftReport `
    /TargetServerName:"$Server" `
    /TargetDatabaseName:"$Database" `
    /TargetUser:"$env:SQL_USERNAME" `
    /TargetPassword:"$env:SQL_PASSWORD" `
    /TargetTrustServerCertificate:True `
    /OutputPath:"$OutputPath"

if ($LASTEXITCODE -ne 0) {

    Write-Error @"
SqlPackage DriftReport failed.

The database may not be registered as a Data-tier Application.

Run the bootstrap registration procedure before using
automated drift detection.
"@

    exit 1
}

# ------------------------------------------------------------
# Validate report
# ------------------------------------------------------------

if (-not (Test-Path $OutputPath)) {

    Write-Error "DriftReport was not created."
    exit 1
}

$ReportContent = Get-Content $OutputPath -Raw

# ------------------------------------------------------------
# No drift
#
# SqlPackage creates an empty report when there are no
# changes since the last registration.
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($ReportContent)) {

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
Write-Host "The database has changed since the last"
Write-Host "registered deployment."
Write-Host ""

Write-Host "Drift report:"
Write-Host $OutputPath
Write-Host ""

Write-Host "CI/CD deployment will stop."
Write-Host ""

exit 1