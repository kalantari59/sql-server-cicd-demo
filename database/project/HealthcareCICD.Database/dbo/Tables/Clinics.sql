CREATE TABLE [dbo].[Clinics] (
    [ClinicId]     INT            IDENTITY (1, 1) NOT NULL,
    [ClinicName]   NVARCHAR (150) NOT NULL,
    [DepartmentId] INT            NOT NULL,
    [City]         NVARCHAR (100) NOT NULL,
    [IsActive]     BIT            CONSTRAINT [DF_Clinics_IsActive] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_Clinics] PRIMARY KEY CLUSTERED ([ClinicId] ASC),
    CONSTRAINT [FK_Clinics_Departments] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([DepartmentId]),
    CONSTRAINT [UQ_Clinics_ClinicName] UNIQUE NONCLUSTERED ([ClinicName] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_Clinics_DepartmentId]
    ON [dbo].[Clinics]([DepartmentId] ASC);

