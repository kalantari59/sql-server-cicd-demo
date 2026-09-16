CREATE   PROCEDURE dbo.usp_GetPatientAppointments
    @PatientId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.AppointmentId,
        a.AppointmentDateTime,
        a.Status,
        CONCAT(pr.FirstName, ' ', pr.LastName) AS ProviderName,
        c.ClinicName
    FROM dbo.Appointments AS a
    INNER JOIN dbo.Providers AS pr
        ON a.ProviderId = pr.ProviderId
    INNER JOIN dbo.Clinics AS c
        ON a.ClinicId = c.ClinicId
    WHERE a.PatientId = @PatientId
    ORDER BY a.AppointmentDateTime;
END;
