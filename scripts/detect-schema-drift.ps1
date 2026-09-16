param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [string]$Database = "HealthcareCICD",

    [string]$DacpacPath = "",

    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot

# Default DACPAC location
if ([string]::IsNullOrWhiteSpace($DacpacPath)) {
    $DacpacPath = Join-Path `
        $ProjectRoot `
        "database\project\HealthcareCICD.Database\HealthcareCICD.Database\bin\Debug\HealthcareCICD.Database.dacpac"
}

# Default deployment plan location
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path `
        $ProjectRoot `
        "schema-drift-check.sql"
}

Write-Host "========================================"
Write-Host "SQL Server Schema Drift Detection"
Write-Host "========================================"
Write-Host "Server:   $Server"
Write-Host "Database: $Database"
Write-Host "DACPAC:   $DacpacPath"
Write-Host ""

# --------------------------------------------------
# Step 1 - Validate prerequisites
# --------------------------------------------------

if (-not (Test-Path $DacpacPath)) {
    Write-Error "DACPAC not found: $DacpacPath"
    exit 1
}

if (-not (Get-Command sqlpackage -ErrorAction SilentlyContinue)) {
    Write-Error "SqlPackage was not found in PATH."
    exit 1
}

# --------------------------------------------------
# Step 2 - Generate deployment plan
# --------------------------------------------------

Write-Host "Generating deployment plan..."

$TargetConnectionString = `
    "Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True"

sqlpackage `
    /Action:Script `
    /SourceFile:"$DacpacPath" `
    /TargetConnectionString:"$TargetConnectionString" `
    /DeployScriptPath:"$OutputPath"

if ($LASTEXITCODE -ne 0) {
    Write-Error "SqlPackage failed while generating the deployment plan."
    exit 1
}

Write-Host ""
Write-Host "Deployment plan generated:"
Write-Host $OutputPath

# --------------------------------------------------
# Step 3 - Read deployment plan
# --------------------------------------------------

if (-not (Test-Path $OutputPath)) {
    Write-Error "Deployment plan was not created."
    exit 1
}

$PlanContent = Get-Content $OutputPath -Raw

# --------------------------------------------------
# Step 4 - Detect actual schema changes
# --------------------------------------------------

$SchemaPatterns = @(
    "CREATE TABLE",
    "ALTER TABLE",
    "DROP TABLE",
    "CREATE VIEW",
    "ALTER VIEW",
    "DROP VIEW",
    "CREATE PROCEDURE",
    "ALTER PROCEDURE",
    "DROP PROCEDURE",
    "CREATE FUNCTION",
    "ALTER FUNCTION",
    "DROP FUNCTION",
    "ADD CONSTRAINT",
    "DROP CONSTRAINT"
)

$SchemaChanges = @()

foreach ($Pattern in $SchemaPatterns) {

    $Matches = Select-String `
        -InputObject $PlanContent `
        -Pattern $Pattern `
        -AllMatches

    if ($Matches) {
        $SchemaChanges += $Pattern
    }
}

# --------------------------------------------------
# Step 5 - Return CI/CD result
# --------------------------------------------------

Write-Host ""

if ($SchemaChanges.Count -gt 0) {

    Write-Host "========================================" -ForegroundColor Red
    Write-Host "SCHEMA DRIFT DETECTED" -ForegroundColor Red
    Write-Host "========================================"

    Write-Host ""
    Write-Host "Schema changes found in the deployment plan:"

    foreach ($Change in $SchemaChanges) {
        Write-Host "  - $Change" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "The actual SQL Server schema differs from the DACPAC."
    Write-Host "CI/CD deployment should stop."

    exit 1
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "NO SCHEMA DRIFT DETECTED" -ForegroundColor Green
Write-Host "========================================"

Write-Host "The actual SQL Server schema matches the DACPAC."

exit 0