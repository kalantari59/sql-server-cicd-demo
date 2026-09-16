CREATE TABLE [dbo].[Appointments] (
    [AppointmentId]       INT           IDENTITY (1, 1) NOT NULL,
    [PatientId]           INT           NOT NULL,
    [ProviderId]          INT           NOT NULL,
    [ClinicId]            INT           NOT NULL,
    [AppointmentDateTime] DATETIME2 (0) NOT NULL,
    [Status]              NVARCHAR (20) NOT NULL,
    CONSTRAINT [PK_Appointments] PRIMARY KEY CLUSTERED ([AppointmentId] ASC),
    CONSTRAINT [CK_Appointments_Status] CHECK ([Status]='Cancelled' OR [Status]='Completed' OR [Status]='Scheduled'),
    CONSTRAINT [FK_Appointments_Clinics] FOREIGN KEY ([ClinicId]) REFERENCES [dbo].[Clinics] ([ClinicId]),
    CONSTRAINT [FK_Appointments_Patients] FOREIGN KEY ([PatientId]) REFERENCES [dbo].[Patients] ([PatientId]),
    CONSTRAINT [FK_Appointments_Providers] FOREIGN KEY ([ProviderId]) REFERENCES [dbo].[Providers] ([ProviderId])
);


GO
CREATE NONCLUSTERED INDEX [IX_Appointments_PatientId]
    ON [dbo].[Appointments]([PatientId] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_Appointments_ProviderDate]
    ON [dbo].[Appointments]([ProviderId] ASC, [AppointmentDateTime] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_Appointments_ClinicDate]
    ON [dbo].[Appointments]([ClinicId] ASC, [AppointmentDateTime] ASC);

