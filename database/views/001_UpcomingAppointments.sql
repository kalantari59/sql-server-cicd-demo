CREATE OR ALTER VIEW dbo.vw_UpcomingAppointments
AS
SELECT
    a.AppointmentId,
    p.PatientId,
    CONCAT(p.FirstName, ' ', p.LastName) AS PatientName,
    CONCAT(pr.FirstName, ' ', pr.LastName) AS ProviderName,
    c.ClinicName,
    a.AppointmentDateTime,
    a.Status
FROM dbo.Appointments AS a
INNER JOIN dbo.Patients AS p
    ON a.PatientId = p.PatientId
INNER JOIN dbo.Providers AS pr
    ON a.ProviderId = pr.ProviderId
INNER JOIN dbo.Clinics AS c
    ON a.ClinicId = c.ClinicId
WHERE a.AppointmentDateTime >= SYSUTCDATETIME();
