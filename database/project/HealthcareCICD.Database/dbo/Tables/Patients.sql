CREATE TABLE [dbo].[Patients] (
    [PatientId]   INT            IDENTITY (1, 1) NOT NULL,
    [FirstName]   NVARCHAR (50)  NOT NULL,
    PhoneNumber NVARCHAR(30) NULL,
    EmergencyContactName NVARCHAR(100) NULL,
    EmergencyContactFamily NVARCHAR(100) NULL,
    [LastName]    NVARCHAR (50)  NOT NULL,
    [DateOfBirth] DATE           NOT NULL,
    [Email]       NVARCHAR (255) NULL,
    [Email12]       NVARCHAR (255) NULL,
    [IsActive]    BIT            CONSTRAINT [DF_Patients_IsActive] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_Patients] PRIMARY KEY CLUSTERED ([PatientId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_Patients_LastName]
    ON [dbo].[Patients]([LastName] ASC);

