IF OBJECT_ID(N'dbo.Departments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Departments
    (
        DepartmentId INT IDENTITY(1,1) NOT NULL,
        DepartmentName NVARCHAR(100) NOT NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_Departments_IsActive DEFAULT (1),

        CONSTRAINT PK_Departments
            PRIMARY KEY (DepartmentId),

        CONSTRAINT UQ_Departments_DepartmentName
            UNIQUE (DepartmentName)
    );
END;
