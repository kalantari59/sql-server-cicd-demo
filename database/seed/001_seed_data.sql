USE HealthcareCICD;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Departments
    WHERE DepartmentName = 'Cardiology'
)
BEGIN
    INSERT INTO dbo.Departments (DepartmentName)
    VALUES ('Cardiology');
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Departments
    WHERE DepartmentName = 'Family Medicine'
)
BEGIN
    INSERT INTO dbo.Departments (DepartmentName)
    VALUES ('Family Medicine');
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Departments
    WHERE DepartmentName = 'Pediatrics'
)
BEGIN
    INSERT INTO dbo.Departments (DepartmentName)
    VALUES ('Pediatrics');
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Clinics
    WHERE ClinicName = 'Northstar Cardiology Clinic'
)
BEGIN
    INSERT INTO dbo.Clinics
    (
        ClinicName,
        DepartmentId,
        City
    )
    SELECT
        'Northstar Cardiology Clinic',
        DepartmentId,
        'Toronto'
    FROM dbo.Departments
    WHERE DepartmentName = 'Cardiology';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Clinics
    WHERE ClinicName = 'Northstar Family Clinic'
)
BEGIN
    INSERT INTO dbo.Clinics
    (
        ClinicName,
        DepartmentId,
        City
    )
    SELECT
        'Northstar Family Clinic',
        DepartmentId,
        'Vaughan'
    FROM dbo.Departments
    WHERE DepartmentName = 'Family Medicine';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Clinics
    WHERE ClinicName = 'Northstar Pediatrics Clinic'
)
BEGIN
    INSERT INTO dbo.Clinics
    (
        ClinicName,
        DepartmentId,
        City
    )
    SELECT
        'Northstar Pediatrics Clinic',
        DepartmentId,
        'Toronto'
    FROM dbo.Departments
    WHERE DepartmentName = 'Pediatrics';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Providers
    WHERE Email = 'alex.morgan@example.test'
)
BEGIN
    INSERT INTO dbo.Providers
    (
        FirstName,
        LastName,
        DepartmentId,
        Email
    )
    SELECT
        'Alex',
        'Morgan',
        DepartmentId,
        'alex.morgan@example.test'
    FROM dbo.Departments
    WHERE DepartmentName = 'Cardiology';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Providers
    WHERE Email = 'taylor.patel@example.test'
)
BEGIN
    INSERT INTO dbo.Providers
    (
        FirstName,
        LastName,
        DepartmentId,
        Email
    )
    SELECT
        'Taylor',
        'Patel',
        DepartmentId,
        'taylor.patel@example.test'
    FROM dbo.Departments
    WHERE DepartmentName = 'Family Medicine';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Providers
    WHERE Email = 'jordan.lee@example.test'
)
BEGIN
    INSERT INTO dbo.Providers
    (
        FirstName,
        LastName,
        DepartmentId,
        Email
    )
    SELECT
        'Jordan',
        'Lee',
        DepartmentId,
        'jordan.lee@example.test'
    FROM dbo.Departments
    WHERE DepartmentName = 'Pediatrics';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Patients
    WHERE Email = 'sam.carter@example.test'
)
BEGIN
    INSERT INTO dbo.Patients
    (
        FirstName,
        LastName,
        DateOfBirth,
        Email
    )
    VALUES
    (
        'Sam',
        'Carter',
        '1985-04-12',
        'sam.carter@example.test'
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Patients
    WHERE Email = 'jamie.wilson@example.test'
)
BEGIN
    INSERT INTO dbo.Patients
    (
        FirstName,
        LastName,
        DateOfBirth,
        Email
    )
    VALUES
    (
        'Jamie',
        'Wilson',
        '1992-08-21',
        'jamie.wilson@example.test'
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Patients
    WHERE Email = 'chris.brown@example.test'
)
BEGIN
    INSERT INTO dbo.Patients
    (
        FirstName,
        LastName,
        DateOfBirth,
        Email
    )
    VALUES
    (
        'Chris',
        'Brown',
        '1978-11-03',
        'chris.brown@example.test'
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Appointments AS a
    INNER JOIN dbo.Patients AS p
        ON a.PatientId = p.PatientId
    WHERE p.Email = 'sam.carter@example.test'
)
BEGIN
    INSERT INTO dbo.Appointments
    (
        PatientId,
        ProviderId,
        ClinicId,
        AppointmentDateTime,
        Status
    )
    SELECT
        p.PatientId,
        pr.ProviderId,
        c.ClinicId,
        DATEADD(DAY, 1, SYSUTCDATETIME()),
        'Scheduled'
    FROM dbo.Patients AS p
    CROSS JOIN dbo.Providers AS pr
    CROSS JOIN dbo.Clinics AS c
    WHERE p.Email = 'sam.carter@example.test'
      AND pr.Email = 'alex.morgan@example.test'
      AND c.ClinicName = 'Northstar Cardiology Clinic';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Appointments AS a
    INNER JOIN dbo.Patients AS p
        ON a.PatientId = p.PatientId
    WHERE p.Email = 'jamie.wilson@example.test'
)
BEGIN
    INSERT INTO dbo.Appointments
    (
        PatientId,
        ProviderId,
        ClinicId,
        AppointmentDateTime,
        Status
    )
    SELECT
        p.PatientId,
        pr.ProviderId,
        c.ClinicId,
        DATEADD(DAY, 2, SYSUTCDATETIME()),
        'Scheduled'
    FROM dbo.Patients AS p
    CROSS JOIN dbo.Providers AS pr
    CROSS JOIN dbo.Clinics AS c
    WHERE p.Email = 'jamie.wilson@example.test'
      AND pr.Email = 'taylor.patel@example.test'
      AND c.ClinicName = 'Northstar Family Clinic';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Appointments AS a
    INNER JOIN dbo.Patients AS p
        ON a.PatientId = p.PatientId
    WHERE p.Email = 'chris.brown@example.test'
)
BEGIN
    INSERT INTO dbo.Appointments
    (
        PatientId,
        ProviderId,
        ClinicId,
        AppointmentDateTime,
        Status
    )
    SELECT
        p.PatientId,
        pr.ProviderId,
        c.ClinicId,
        DATEADD(DAY, 3, SYSUTCDATETIME()),
        'Scheduled'
    FROM dbo.Patients AS p
    CROSS JOIN dbo.Providers AS pr
    CROSS JOIN dbo.Clinics AS c
    WHERE p.Email = 'chris.brown@example.test'
      AND pr.Email = 'jordan.lee@example.test'
      AND c.ClinicName = 'Northstar Pediatrics Clinic';
END;
