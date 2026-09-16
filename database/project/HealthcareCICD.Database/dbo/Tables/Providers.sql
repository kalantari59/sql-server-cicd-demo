CREATE TABLE [dbo].[Providers] (
    [ProviderId]   INT            IDENTITY (1, 1) NOT NULL,
    [FirstName]    NVARCHAR (50)  NOT NULL,
    [LastName]     NVARCHAR (50)  NOT NULL,
    [DepartmentId] INT            NOT NULL,
    [Email]        NVARCHAR (255) NOT NULL,
    [IsActive]     BIT            CONSTRAINT [DF_Providers_IsActive] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_Providers] PRIMARY KEY CLUSTERED ([ProviderId] ASC),
    CONSTRAINT [FK_Providers_Departments] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([DepartmentId]),
    CONSTRAINT [UQ_Providers_Email] UNIQUE NONCLUSTERED ([Email] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_Providers_DepartmentId]
    ON [dbo].[Providers]([DepartmentId] ASC);

