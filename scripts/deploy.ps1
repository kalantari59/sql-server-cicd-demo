param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [string]$Database = "HealthcareCICD",

    [string]$CommitSha = "LOCAL",

    [string]$Environment = "Development"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TablePath = Join-Path $ProjectRoot "database\tables"

Write-Host "========================================"
Write-Host "SQL Server CI/CD Deployment"
Write-Host "========================================"
Write-Host "Server:      $Server"
Write-Host "Database:    $Database"
Write-Host "Environment: $Environment"
Write-Host "Commit SHA:  $CommitSha"
Write-Host ""

function Invoke-SqlFile {
    param(
        [string]$FilePath,
        [string]$TargetDatabase = "master"
    )

    Write-Host "Executing: $FilePath"

    sqlcmd `
        -S $Server `
        -d $TargetDatabase `
        -E `
        -b `
        -i $FilePath

    if ($LASTEXITCODE -ne 0) {
        throw "SQL execution failed: $FilePath"
    }
}

try {

    # Step 1 - Create database
    $CreateDatabaseScript = Join-Path $ProjectRoot "database\deploy\001_create_database.sql"

    Invoke-SqlFile `
        -FilePath $CreateDatabaseScript `
        -TargetDatabase "master"

    # Step 2 - Deploy tables
    $TableFiles = Get-ChildItem $TablePath -Filter "*.sql" |
        Sort-Object Name

    foreach ($File in $TableFiles) {

        Invoke-SqlFile `
            -FilePath $File.FullName `
            -TargetDatabase $Database
    }
# Step 3 - Deploy views
$ViewPath = Join-Path $ProjectRoot "database\views"

$ViewFiles = Get-ChildItem $ViewPath -Filter "*.sql" |
    Sort-Object Name

foreach ($File in $ViewFiles) {

    Invoke-SqlFile `
        -FilePath $File.FullName `
        -TargetDatabase $Database
}

# Step 4 - Deploy stored procedures
$ProcedurePath = Join-Path $ProjectRoot "database\procedures"

$ProcedureFiles = Get-ChildItem $ProcedurePath -Filter "*.sql" |
    Sort-Object Name

foreach ($File in $ProcedureFiles) {

    Invoke-SqlFile `
        -FilePath $File.FullName `
        -TargetDatabase $Database
}

# Step 5 - Seed synthetic data
$SeedPath = Join-Path $ProjectRoot "database\seed"

$SeedFiles = Get-ChildItem $SeedPath -Filter "*.sql" |
    Sort-Object Name

foreach ($File in $SeedFiles) {

    Invoke-SqlFile `
        -FilePath $File.FullName `
        -TargetDatabase $Database
}

# Step 3 - Create deployment log table
$LoggingSql = @"
IF OBJECT_ID(N'dbo.DeploymentLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DeploymentLog
    (
        DeploymentId INT IDENTITY(1,1) NOT NULL,
        DeploymentDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_DeploymentLog_DeploymentDate
            DEFAULT SYSUTCDATETIME(),
        CommitSha NVARCHAR(100) NOT NULL,
        Environment NVARCHAR(50) NOT NULL,
        Status NVARCHAR(20) NOT NULL,
        ExecutedBy NVARCHAR(255) NOT NULL,
        ErrorMessage NVARCHAR(4000) NULL,

        CONSTRAINT PK_DeploymentLog
            PRIMARY KEY (DeploymentId)
    );
END;
"@

    $TempLogFile = Join-Path $env:TEMP "create-deployment-log.sql"

    $LoggingSql | Set-Content $TempLogFile

    Invoke-SqlFile `
        -FilePath $TempLogFile `
        -TargetDatabase $Database

    Remove-Item $TempLogFile -Force

    # Step 4 - Log successful deployment
    $ExecutedBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    $LogSql = @"
INSERT INTO dbo.DeploymentLog
(
    CommitSha,
    Environment,
    Status,
    ExecutedBy,
    ErrorMessage
)
VALUES
(
    '$CommitSha',
    '$Environment',
    'SUCCESS',
    '$ExecutedBy',
    NULL
);
"@

    $TempLogFile = Join-Path $env:TEMP "deployment-success.sql"

    $LogSql | Set-Content $TempLogFile

    Invoke-SqlFile `
        -FilePath $TempLogFile `
        -TargetDatabase $Database

    Remove-Item $TempLogFile -Force

    Write-Host ""
    Write-Host "Deployment completed successfully." -ForegroundColor Green
}
catch {

    Write-Host ""
    Write-Host "Deployment FAILED." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}
