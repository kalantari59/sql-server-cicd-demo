param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [string]$Database = "HealthcareCICD"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "SQL Server Schema Validation"
Write-Host "========================================"
Write-Host "Server:   $Server"
Write-Host "Database: $Database"
Write-Host ""

function Invoke-ValidationQuery {
    param(
        [string]$Query
    )

    sqlcmd `
        -S $Server `
        -d $Database `
        -E `
        -b `
        -Q $Query

    if ($LASTEXITCODE -ne 0) {
        throw "Schema validation query failed."
    }
}

$Query = @"
SET NOCOUNT ON;

DECLARE @Failures INT = 0;

PRINT 'Checking required tables...';

IF OBJECT_ID(N'dbo.Departments', N'U') IS NULL
BEGIN
    PRINT 'FAIL: dbo.Departments is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: dbo.Departments exists';

IF OBJECT_ID(N'dbo.Clinics', N'U') IS NULL
BEGIN
    PRINT 'FAIL: dbo.Clinics is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: dbo.Clinics exists';

IF OBJECT_ID(N'dbo.Providers', N'U') IS NULL
BEGIN
    PRINT 'FAIL: dbo.Providers is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: dbo.Providers exists';

IF OBJECT_ID(N'dbo.Patients', N'U') IS NULL
BEGIN
    PRINT 'FAIL: dbo.Patients is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: dbo.Patients exists';

IF OBJECT_ID(N'dbo.Appointments', N'U') IS NULL
BEGIN
    PRINT 'FAIL: dbo.Appointments is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: dbo.Appointments exists';

PRINT 'Checking views...';

IF OBJECT_ID(N'dbo.vw_UpcomingAppointments', N'V') IS NULL
BEGIN
    PRINT 'FAIL: vw_UpcomingAppointments is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: vw_UpcomingAppointments exists';

IF OBJECT_ID(N'dbo.vw_ProviderSchedule', N'V') IS NULL
BEGIN
    PRINT 'FAIL: vw_ProviderSchedule is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: vw_ProviderSchedule exists';

PRINT 'Checking stored procedure...';

IF OBJECT_ID(N'dbo.usp_GetPatientAppointments', N'P') IS NULL
BEGIN
    PRINT 'FAIL: usp_GetPatientAppointments is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: usp_GetPatientAppointments exists';

PRINT 'Checking required columns...';

IF COL_LENGTH('dbo.Patients', 'DateOfBirth') IS NULL
BEGIN
    PRINT 'FAIL: Patients.DateOfBirth is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: Patients.DateOfBirth exists';

IF COL_LENGTH('dbo.Appointments', 'AppointmentDateTime') IS NULL
BEGIN
    PRINT 'FAIL: Appointments.AppointmentDateTime is missing';
    SET @Failures += 1;
END
ELSE
    PRINT 'PASS: Appointments.AppointmentDateTime exists';

PRINT '----------------------------------------';

IF @Failures > 0
BEGIN
    PRINT 'SCHEMA VALIDATION FAILED';
    PRINT 'Failures: ' + CAST(@Failures AS VARCHAR(10));

    RAISERROR('Schema validation failed.', 16, 1);
END
ELSE
BEGIN
    PRINT 'SCHEMA VALIDATION PASSED';
END;
"@

Invoke-ValidationQuery -Query $Query
