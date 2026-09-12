IF OBJECT_ID(N'dbo.Appointments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Appointments
    (
        AppointmentId INT IDENTITY(1,1) NOT NULL,
        PatientId INT NOT NULL,
        ProviderId INT NOT NULL,
        ClinicId INT NOT NULL,
        AppointmentDateTime DATETIME2(0) NOT NULL,
        Status NVARCHAR(20) NOT NULL,

        CONSTRAINT PK_Appointments
            PRIMARY KEY (AppointmentId),

        CONSTRAINT FK_Appointments_Patients
            FOREIGN KEY (PatientId)
            REFERENCES dbo.Patients(PatientId),

        CONSTRAINT FK_Appointments_Providers
            FOREIGN KEY (ProviderId)
            REFERENCES dbo.Providers(ProviderId),

        CONSTRAINT FK_Appointments_Clinics
            FOREIGN KEY (ClinicId)
            REFERENCES dbo.Clinics(ClinicId),

        CONSTRAINT CK_Appointments_Status
            CHECK (Status IN ('Scheduled', 'Completed', 'Cancelled'))
    );

    CREATE INDEX IX_Appointments_PatientId
    ON dbo.Appointments(PatientId);

    CREATE INDEX IX_Appointments_ProviderDate
    ON dbo.Appointments(ProviderId, AppointmentDateTime);

    CREATE INDEX IX_Appointments_ClinicDate
    ON dbo.Appointments(ClinicId, AppointmentDateTime);
END;
