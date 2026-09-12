USE HealthcareCICD;
GO

SET NOCOUNT ON;

DECLARE @FailedTests INT = 0;

PRINT '========================================';
PRINT 'Database CI/CD Tests';
PRINT '========================================';

--------------------------------------------------
-- Test 1: Required tables
--------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Departments')
BEGIN
    PRINT 'FAIL: Departments table is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Departments table exists';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Clinics')
BEGIN
    PRINT 'FAIL: Clinics table is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Clinics table exists';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Providers')
BEGIN
    PRINT 'FAIL: Providers table is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Providers table exists';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Patients')
BEGIN
    PRINT 'FAIL: Patients table is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Patients table exists';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Appointments')
BEGIN
    PRINT 'FAIL: Appointments table is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Appointments table exists';

--------------------------------------------------
-- Test 2: Required columns
--------------------------------------------------

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.Patients')
      AND name = 'DateOfBirth'
)
BEGIN
    PRINT 'FAIL: Patients.DateOfBirth is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Patients.DateOfBirth exists';

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.Appointments')
      AND name = 'AppointmentDateTime'
)
BEGIN
    PRINT 'FAIL: Appointments.AppointmentDateTime is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Appointments.AppointmentDateTime exists';

--------------------------------------------------
-- Test 3: Views
--------------------------------------------------

IF NOT EXISTS
(
    SELECT 1
    FROM sys.views
    WHERE name = 'vw_UpcomingAppointments'
)
BEGIN
    PRINT 'FAIL: vw_UpcomingAppointments is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: vw_UpcomingAppointments exists';

IF NOT EXISTS
(
    SELECT 1
    FROM sys.views
    WHERE name = 'vw_ProviderSchedule'
)
BEGIN
    PRINT 'FAIL: vw_ProviderSchedule is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: vw_ProviderSchedule exists';

--------------------------------------------------
-- Test 4: Stored procedure
--------------------------------------------------

IF NOT EXISTS
(
    SELECT 1
    FROM sys.procedures
    WHERE name = 'usp_GetPatientAppointments'
)
BEGIN
    PRINT 'FAIL: usp_GetPatientAppointments is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: usp_GetPatientAppointments exists';

--------------------------------------------------
-- Test 5: Foreign keys
--------------------------------------------------

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = 'FK_Clinics_Departments'
)
BEGIN
    PRINT 'FAIL: FK_Clinics_Departments is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: FK_Clinics_Departments exists';

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = 'FK_Appointments_Patients'
)
BEGIN
    PRINT 'FAIL: FK_Appointments_Patients is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: FK_Appointments_Patients exists';

--------------------------------------------------
-- Test 6: Seed data
--------------------------------------------------

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Departments
)
BEGIN
    PRINT 'FAIL: Department seed data is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Department seed data exists';

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Patients
)
BEGIN
    PRINT 'FAIL: Patient seed data is missing';
    SET @FailedTests += 1;
END
ELSE
    PRINT 'PASS: Patient seed data exists';

--------------------------------------------------
-- Final result
--------------------------------------------------

PRINT '----------------------------------------';

IF @FailedTests > 0
BEGIN
    PRINT 'DATABASE TESTS FAILED';
    PRINT 'Failed tests: ' + CAST(@FailedTests AS VARCHAR(10));
    RAISERROR('Database validation failed.', 16, 1);
END
ELSE
BEGIN
    PRINT 'ALL DATABASE TESTS PASSED';
END;
