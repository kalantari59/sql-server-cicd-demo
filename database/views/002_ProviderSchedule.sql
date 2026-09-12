CREATE OR ALTER VIEW dbo.vw_ProviderSchedule
AS
SELECT
    pr.ProviderId,
    CONCAT(pr.FirstName, ' ', pr.LastName) AS ProviderName,
    d.DepartmentName,
    a.AppointmentId,
    a.AppointmentDateTime,
    a.Status
FROM dbo.Providers AS pr
INNER JOIN dbo.Departments AS d
    ON pr.DepartmentId = d.DepartmentId
LEFT JOIN dbo.Appointments AS a
    ON pr.ProviderId = a.ProviderId;
