IF OBJECT_ID(N'dbo.Clinics', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Clinics
    (
        ClinicId INT IDENTITY(1,1) NOT NULL,
        ClinicName NVARCHAR(150) NOT NULL,
        DepartmentId INT NOT NULL,
        City NVARCHAR(100) NOT NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_Clinics_IsActive DEFAULT (1),

        CONSTRAINT PK_Clinics
            PRIMARY KEY (ClinicId),

        CONSTRAINT FK_Clinics_Departments
            FOREIGN KEY (DepartmentId)
            REFERENCES dbo.Departments(DepartmentId),

        CONSTRAINT UQ_Clinics_ClinicName
            UNIQUE (ClinicName)
    );

    CREATE INDEX IX_Clinics_DepartmentId
    ON dbo.Clinics(DepartmentId);
END;
