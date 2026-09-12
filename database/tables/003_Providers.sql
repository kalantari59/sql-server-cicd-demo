IF OBJECT_ID(N'dbo.Providers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Providers
    (
        ProviderId INT IDENTITY(1,1) NOT NULL,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        DepartmentId INT NOT NULL,
        Email NVARCHAR(255) NOT NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_Providers_IsActive DEFAULT (1),

        CONSTRAINT PK_Providers
            PRIMARY KEY (ProviderId),

        CONSTRAINT FK_Providers_Departments
            FOREIGN KEY (DepartmentId)
            REFERENCES dbo.Departments(DepartmentId),

        CONSTRAINT UQ_Providers_Email
            UNIQUE (Email)
    );

    CREATE INDEX IX_Providers_DepartmentId
    ON dbo.Providers(DepartmentId);
END;
