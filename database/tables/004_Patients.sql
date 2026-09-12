IF OBJECT_ID(N'dbo.Patients', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Patients
    (
        PatientId INT IDENTITY(1,1) NOT NULL,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        DateOfBirth DATE NOT NULL,
        Email NVARCHAR(255) NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_Patients_IsActive DEFAULT (1),

        CONSTRAINT PK_Patients
            PRIMARY KEY (PatientId)
    );

    CREATE INDEX IX_Patients_LastName
    ON dbo.Patients(LastName);
END;
