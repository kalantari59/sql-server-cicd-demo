CREATE TABLE [dbo].[Departments] (
    [DepartmentId]   INT            IDENTITY (1, 1) NOT NULL,
    [DepartmentName] NVARCHAR (100) NOT NULL,
    [IsActive]       BIT            CONSTRAINT [DF_Departments_IsActive] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_Departments] PRIMARY KEY CLUSTERED ([DepartmentId] ASC),
    CONSTRAINT [UQ_Departments_DepartmentName] UNIQUE NONCLUSTERED ([DepartmentName] ASC)
);

