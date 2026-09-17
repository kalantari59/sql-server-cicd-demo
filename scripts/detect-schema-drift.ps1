[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [string]$DacpacPath = ".\database\project\HealthcareCICD.Database\bin\Debug\HealthcareCICD.Database.dacpac",

    [string]$OutputPath = ".\drift-report.xml",

    [string]$DeployScriptPath = ".\current-deploy.sql"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "SQL Server Schema Drift Detection"
Write-Host "========================================"
Write-Host "Server:       $Server"
Write-Host "Database:     $Database"
Write-Host "DACPAC:       $DacpacPath"
Write-Host "Report:       $OutputPath"
Write-Host "DeployScript: $DeployScriptPath"
Write-Host ""

# ============================================================
# 1. Validate tools
# ============================================================

$sqlPackage = Get-Command sqlpackage -ErrorAction SilentlyContinue

if (-not $sqlPackage) {
    Write-Error "SqlPackage was not found in PATH."
    exit 1
}

Write-Host "SqlPackage found."

$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue

if (-not $sqlcmd) {
    Write-Error "sqlcmd was not found in PATH."
    exit 1
}

Write-Host "sqlcmd found."

# ============================================================
# 2. Validate credentials
# ============================================================

if ([string]::IsNullOrWhiteSpace($env:SQL_USERNAME)) {
    Write-Error "SQL_USERNAME environment variable is not set."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:SQL_PASSWORD)) {
    Write-Error "SQL_PASSWORD environment variable is not set."
    exit 1
}

Write-Host "SQL credentials are available."

# ============================================================
# 3. Validate DACPAC
# ============================================================

if (-not (Test-Path $DacpacPath)) {
    Write-Error "DACPAC not found: $DacpacPath"
    exit 1
}

$resolvedDacpac = (Resolve-Path $DacpacPath).Path

Write-Host "DACPAC found."
Write-Host ""

# ============================================================
# 4. Generate DriftReport
# ============================================================

Write-Host "Generating SQL Server DriftReport..."
Write-Host ""

if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Force
}

& sqlpackage `
    /Action:DriftReport `
    /TargetServerName:"$Server" `
    /TargetDatabaseName:"$Database" `
    /TargetUser:"$env:SQL_USERNAME" `
    /TargetPassword:"$env:SQL_PASSWORD" `
    /TargetTrustServerCertificate:True `
    /OutputPath:"$OutputPath"

if ($LASTEXITCODE -ne 0) {
    Write-Error "SqlPackage DriftReport failed."
    exit 1
}

Write-Host ""
Write-Host "DriftReport generated successfully."
Write-Host ""

# ============================================================
# 5. Read DriftReport XML
# ============================================================

[xml]$reportXml = Get-Content -Path $OutputPath -Raw

$namespace = New-Object System.Xml.XmlNamespaceManager($reportXml.NameTable)

$namespace.AddNamespace(
    "d",
    "http://schemas.microsoft.com/sqlserver/dac/DriftReport/2012/02"
)

$additions = @(
    $reportXml.SelectNodes(
        "//d:Additions/d:Object",
        $namespace
    )
)

$removals = @(
    $reportXml.SelectNodes(
        "//d:Removals/d:Object",
        $namespace
    )
)

$modifications = @(
    $reportXml.SelectNodes(
        "//d:Modifications/d:Object",
        $namespace
    )
)

$driftObjects = @($additions) + @($removals) + @($modifications)

Write-Host "DriftReport summary:"
Write-Host "  Additions found:        $($additions.Count)"
Write-Host "  Removals found:         $($removals.Count)"
Write-Host "  Modifications found:    $($modifications.Count)"
Write-Host "  Total drift objects:    $($driftObjects.Count)"
Write-Host ""

# ============================================================
# 6. Display DriftReport details
# ============================================================

function Write-DriftObjects {
    param(
        [string]$Title,
        [object[]]$Objects
    )

    if ($Objects.Count -eq 0) {
        return
    }

    Write-Host $Title

    foreach ($object in $Objects) {
        $parent = [string]$object.Parent

        if ([string]::IsNullOrWhiteSpace($parent)) {
            $parent = "<database>"
        }

        Write-Host "  Name: $($object.Name)"
        Write-Host "  Parent: $parent"
        Write-Host "  Type: $($object.Type)"
    }

    Write-Host ""
}

Write-DriftObjects -Title "Drift additions:" -Objects $additions
Write-DriftObjects -Title "Drift removals:" -Objects $removals
Write-DriftObjects -Title "Drift modifications:" -Objects $modifications

# ============================================================
# 7. CLEAN
# ============================================================

if ($driftObjects.Count -eq 0) {
    Write-Host "========================================"
    Write-Host "NO SCHEMA DRIFT DETECTED"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "The actual SQL Server schema matches"
    Write-Host "the last registered deployment baseline."

    exit 0
}

# ============================================================
# 8. Generate DeployReport for detailed deployment diagnostics
#
# DriftReport above determines whether the target database has
# changed outside the registered deployment baseline. DeployReport
# below remains useful diagnostics for the current Git DACPAC and
# must not be used as the drift gate.
# ============================================================

$deployReportPath = "$OutputPath.deploy-report.xml"

Write-Host "Generating DeployReport for detailed deployment diagnostics..."
Write-Host ""

if (Test-Path $deployReportPath) {
    Remove-Item $deployReportPath -Force
}

& sqlpackage `
    /Action:DeployReport `
    /SourceFile:"$resolvedDacpac" `
    /TargetServerName:"$Server" `
    /TargetDatabaseName:"$Database" `
    /TargetUser:"$env:SQL_USERNAME" `
    /TargetPassword:"$env:SQL_PASSWORD" `
    /TargetTrustServerCertificate:True `
    /OutputPath:"$deployReportPath"

if ($LASTEXITCODE -ne 0) {
    Write-Error "SqlPackage DeployReport failed."
    exit 1
}

Write-Host "DeployReport generated successfully."
Write-Host ""

# ============================================================
# 9. Read DeployReport XML for detailed deployment diagnostics
# ============================================================

[xml]$deployReportXml = Get-Content -Path $deployReportPath -Raw

$deployNamespace = New-Object System.Xml.XmlNamespaceManager($deployReportXml.NameTable)

$deployNamespace.AddNamespace(
    "d",
    "http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02"
)

$operations = @(
    $deployReportXml.SelectNodes(
        "//d:Operations/d:Operation",
        $deployNamespace
    )
)

$alerts = @(
    $deployReportXml.SelectNodes(
        "//d:Alerts/d:Alert",
        $deployNamespace
    )
)

$tableRebuildOperations = @(
    $operations |
        Where-Object {
            $_.Name -eq "TableRebuild"
        }
)

$meaningfulOperations = @(
    $operations |
        Where-Object {
            $_.Name -in @(
                "Create",
                "Alter",
                "Drop",
                "TableRebuild"
            )
        }
)

$dataMotionAlerts = @(
    $alerts |
        Where-Object {
            $_.Name -eq "DataMotion"
        }
)

$dataIssueAlerts = @(
    $alerts |
        Where-Object {
            $_.Name -eq "DataIssue"
        }
)

Write-Host "DeployReport diagnostic summary:"
Write-Host "  Operations found:       $($operations.Count)"
Write-Host "  Meaningful changes:     $($meaningfulOperations.Count)"
Write-Host "  Table rebuilds:         $($tableRebuildOperations.Count)"
Write-Host "  Data motion alerts:     $($dataMotionAlerts.Count)"
Write-Host "  Data issue alerts:      $($dataIssueAlerts.Count)"
Write-Host ""

# ============================================================
# 10. Generate deployment script
#
# We use SqlPackage only to generate the deployment plan.
# We do NOT use regex to parse it.
# ============================================================

Write-Host "Generating deployment script for detailed schema comparison..."
Write-Host ""

if (Test-Path $DeployScriptPath) {
    Remove-Item $DeployScriptPath -Force
}

& sqlpackage `
    /Action:Script `
    /SourceFile:"$resolvedDacpac" `
    /TargetServerName:"$Server" `
    /TargetDatabaseName:"$Database" `
    /TargetUser:"$env:SQL_USERNAME" `
    /TargetPassword:"$env:SQL_PASSWORD" `
    /TargetTrustServerCertificate:True `
    /OutputPath:"$DeployScriptPath" `
    /p:BlockOnPossibleDataLoss=False

if ($LASTEXITCODE -ne 0) {
    Write-Error "SqlPackage deployment script generation failed."
    exit 1
}

Write-Host "Deployment script generated successfully."
Write-Host ""

# ============================================================
# 11. Get actual SQL Server columns
# ============================================================

function Get-ActualColumns {
    param(
        [string]$SchemaName,
        [string]$TableName
    )

    $query = @"
SET NOCOUNT ON;

SELECT
    COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = '$SchemaName'
  AND TABLE_NAME = '$TableName'
ORDER BY ORDINAL_POSITION;
"@

    $result = & sqlcmd `
        -S $Server `
        -d $Database `
        -U "$env:SQL_USERNAME" `
        -P "$env:SQL_PASSWORD" `
        -C `
        -h -1 `
        -W `
        -Q $query

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to query SQL Server columns for [$SchemaName].[$TableName]."
    }

    $columns = @()

    foreach ($line in $result) {

        $columnName = $line.ToString().Trim()

        if ([string]::IsNullOrWhiteSpace($columnName)) {
            continue
        }

        $columns += $columnName
    }

    return $columns
}

# ============================================================
# 12. Find tables that SqlPackage wants to rebuild
# ============================================================

$rebuildTables = @()

foreach ($operation in $tableRebuildOperations) {

    foreach ($item in $operation.Item) {

        if ($item.Type -eq "SqlTable") {

            $value = [string]$item.Value

            # Expected format:
            # [dbo].[Patients]

            $parts = $value.Split('.')

            if ($parts.Count -eq 2) {

                $schemaName = $parts[0].Trim('[', ']')
                $tableName = $parts[1].Trim('[', ']')

                $rebuildTables += [PSCustomObject]@{
                    Schema = $schemaName
                    Table  = $tableName
                }
            }
        }
    }
}

# ============================================================
# 13. Read deployment script line by line
#
# We only inspect CREATE TABLE statements generated by
# SqlPackage for temporary rebuild tables.
# No Regex is used.
# ============================================================

$scriptLines = Get-Content -Path $DeployScriptPath

$expectedColumnsByTable = @{}

$insideCreateTable = $false
$currentTableKey = $null

foreach ($line in $scriptLines) {

    $trimmed = $line.Trim()

    # --------------------------------------------------------
    # Detect CREATE TABLE
    # Example:
    #
    # CREATE TABLE [dbo].[tmp_ms_xx_Patients] (
    # --------------------------------------------------------

    if ($trimmed.StartsWith("CREATE TABLE [")) {

        $openParen = $trimmed.IndexOf("(")

        if ($openParen -gt 0) {

            $tablePart = $trimmed.Substring(
                "CREATE TABLE ".Length,
                $openParen - "CREATE TABLE ".Length
            ).Trim()

            # Remove [ and ]
            $tablePart = $tablePart.Replace("[", "")
            $tablePart = $tablePart.Replace("]", "")

            $tableParts = $tablePart.Split(".")

            if ($tableParts.Count -eq 2) {

                $schemaName = $tableParts[0].Trim()
                $tempTableName = $tableParts[1].Trim()

                if ($tempTableName.StartsWith("tmp_ms_xx_")) {

                    $realTableName = $tempTableName.Substring(
                        "tmp_ms_xx_".Length
                    )

                    $currentTableKey = "$schemaName.$realTableName"

                    $expectedColumnsByTable[$currentTableKey] = @()

                    $insideCreateTable = $true

                    continue
                }
            }
        }
    }

    # --------------------------------------------------------
    # Read columns inside CREATE TABLE
    # --------------------------------------------------------

    if ($insideCreateTable) {

        # End of CREATE TABLE
        if ($trimmed -eq ");") {

            $insideCreateTable = $false
            $currentTableKey = $null

            continue
        }

        # Ignore constraints
        if ($trimmed.StartsWith("CONSTRAINT ")) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        # Column lines start with [
        #
        # Example:
        #
        # [EmergencyContactName] NVARCHAR (100) NULL,
        #

        if ($trimmed.StartsWith("[")) {

            $closingBracket = $trimmed.IndexOf("]")

            if ($closingBracket -gt 1) {

                $columnName = $trimmed.Substring(
                    1,
                    $closingBracket - 1
                )

                if (-not $columnName.StartsWith("tmp_ms_xx_")) {

                    $expectedColumnsByTable[$currentTableKey] += $columnName
                }
            }
        }
    }
}

# Debug information
Write-Host "Expected DACPAC columns found in deployment script:"

foreach ($key in $expectedColumnsByTable.Keys) {

    Write-Host "  Table: [$($key.Replace('.', '].['))]"

    foreach ($column in $expectedColumnsByTable[$key]) {

        Write-Host "    $column"
    }
}

Write-Host ""
# ============================================================
# 14. Compare expected DACPAC columns with actual database
# ============================================================

$missingColumns = @()
$unexpectedColumns = @()

foreach ($table in $rebuildTables) {

    $tableKey = "$($table.Schema).$($table.Table)"

    if (-not $expectedColumnsByTable.ContainsKey($tableKey)) {

        Write-Warning "Could not find expected table definition for [$($table.Schema)].[$($table.Table)]."

        continue
    }

    $expectedColumns = @(
        $expectedColumnsByTable[$tableKey]
    )

    $actualColumns = @(
        Get-ActualColumns `
            -SchemaName $table.Schema `
            -TableName $table.Table
    )

    # --------------------------------------------------------
    # Expected in DACPAC but missing in SQL Server
    # --------------------------------------------------------

    foreach ($expectedColumn in $expectedColumns) {

        if ($expectedColumn -notin $actualColumns) {

            $missingColumns += [PSCustomObject]@{
                Schema = $table.Schema
                Table  = $table.Table
                Column = $expectedColumn
            }
        }
    }

    # --------------------------------------------------------
    # Exists in SQL Server but not in DACPAC
    # --------------------------------------------------------

    foreach ($actualColumn in $actualColumns) {

        if ($actualColumn -notin $expectedColumns) {

            $unexpectedColumns += [PSCustomObject]@{
                Schema = $table.Schema
                Table  = $table.Table
                Column = $actualColumn
            }
        }
    }
}

# ============================================================
# 15. Display drift details
# ============================================================

Write-Host "========================================"
Write-Host "SCHEMA DRIFT DETECTED"
Write-Host "========================================"
Write-Host ""

Write-Host "The actual SQL Server database differs"
Write-Host "from the schema represented by the Git DACPAC."
Write-Host ""

# ------------------------------------------------------------
# Missing columns
# ------------------------------------------------------------

if ($missingColumns.Count -gt 0) {

    Write-Host "Columns missing from SQL Server:"

    foreach ($column in $missingColumns) {

        Write-Host "  [$($column.Schema)].[$($column.Table)].[$($column.Column)]"
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Unexpected columns
# ------------------------------------------------------------

if ($unexpectedColumns.Count -gt 0) {

    Write-Host "Unexpected columns in SQL Server:"

    foreach ($column in $unexpectedColumns) {

        Write-Host "  [$($column.Schema)].[$($column.Table)].[$($column.Column)]"
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Table rebuilds
# ------------------------------------------------------------

if ($rebuildTables.Count -gt 0) {

    Write-Host "Table rebuilds:"

    foreach ($table in $rebuildTables) {

        Write-Host "  Table: [$($table.Schema)].[$($table.Table)]"
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Data motion
# ------------------------------------------------------------

if ($dataMotionAlerts.Count -gt 0) {

    Write-Host "Data motion:"

    foreach ($alert in $dataMotionAlerts) {

        foreach ($issue in $alert.Issue) {

            Write-Host "  $($issue.Value)"
        }
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Data issues
# ------------------------------------------------------------

if ($dataIssueAlerts.Count -gt 0) {

    Write-Host "Data issues:"

    foreach ($alert in $dataIssueAlerts) {

        foreach ($issue in $alert.Issue) {

            Write-Host "  $($issue.Value)"
        }
    }

    Write-Host ""
}

# ============================================================
# 16. Dependency operations
# ============================================================

$dependencyCount = 0

foreach ($operation in $operations) {

    foreach ($item in $operation.Item) {

        if ($item.Type -in @(
            "SqlDefaultConstraint",
            "SqlForeignKeyConstraint",
            "SqlIndex"
        )) {

            $dependencyCount++
        }
    }
}

if ($dependencyCount -gt 0) {

    Write-Host "Dependency operations ignored:"
    Write-Host "  $dependencyCount constraint/index operations"
    Write-Host "  were treated as implementation details of schema changes."
    Write-Host ""
}

# ============================================================
# 17. Exit code
# ============================================================

exit 10
