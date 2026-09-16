param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [string]$Database = "HealthcareCICD"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TablePath = Join-Path $ProjectRoot "database\tables"
$ProcedurePath = Join-Path $ProjectRoot "database\procedures"

Write-Host "========================================"
Write-Host "SQL Server Schema Drift Detection"
Write-Host "========================================"
Write-Host "Server:   $Server"
Write-Host "Database: $Database"
Write-Host ""

function Invoke-SqlQuery {
    param(
        [string]$Query
    )

    $Output = sqlcmd `
        -S $Server `
        -d $Database `
        -E `
        -h -1 `
        -W `
        -Q $Query

    if ($LASTEXITCODE -ne 0) {
        throw "SQL query failed."
    }

    return $Output
}

# --------------------------------------------------
# 1. Read expected tables from Git
# --------------------------------------------------

Write-Host "Reading expected tables from Git..."

$ExpectedTables = @()

$TableFiles = Get-ChildItem $TablePath -Filter "*.sql" |
    Sort-Object Name

foreach ($File in $TableFiles) {

    $Content = Get-Content $File.FullName -Raw

    $Match = [regex]::Match(
        $Content,
        '(?i)CREATE\s+TABLE\s+(?:\[dbo\]\.)?\[?([A-Za-z0-9_]+)\]?'
    )

    if ($Match.Success) {
        $ExpectedTables += $Match.Groups[1].Value
    }
}

$ExpectedTables = $ExpectedTables | Sort-Object -Unique

Write-Host "Expected tables:"
$ExpectedTables | ForEach-Object {
    Write-Host "  $_"
}

# --------------------------------------------------
# 2. Read actual tables from SQL Server
# --------------------------------------------------

Write-Host ""
Write-Host "Reading actual tables from SQL Server..."

$TableQuery = @"
SELECT t.name
FROM sys.tables t
INNER JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = 'dbo'
ORDER BY t.name;
"@

$ActualTables = @(Invoke-SqlQuery $TableQuery |
    Where-Object { $_.Trim() -ne "" } |
    ForEach-Object { $_.Trim() })

Write-Host "Actual tables:"
$ActualTables | ForEach-Object {
    Write-Host "  $_"
}

# --------------------------------------------------
# 3. Compare tables
# --------------------------------------------------

Write-Host ""
Write-Host "Comparing tables..."

$MissingTables = @(
    Compare-Object `
        -ReferenceObject $ExpectedTables `
        -DifferenceObject $ActualTables `
        -PassThru |
        Where-Object {
            $_ -in $ExpectedTables
        }
)

$UnexpectedTables = @(
    Compare-Object `
        -ReferenceObject $ExpectedTables `
        -DifferenceObject $ActualTables `
        -PassThru |
        Where-Object {
            $_ -in $ActualTables
        }
)

$DriftDetected = $false

if ($MissingTables.Count -gt 0) {

    $DriftDetected = $true

    Write-Host ""
    Write-Host "Missing tables detected:" -ForegroundColor Red

    foreach ($Table in $MissingTables) {
        Write-Host "  MISSING: $Table" -ForegroundColor Red
    }
}

if ($UnexpectedTables.Count -gt 0) {

    $DriftDetected = $true

    Write-Host ""
    Write-Host "Unexpected tables detected:" -ForegroundColor Red

    foreach ($Table in $UnexpectedTables) {
        Write-Host "  UNEXPECTED: $Table" -ForegroundColor Red
    }
}

if (-not $DriftDetected) {
    Write-Host "PASS: Table structure matches Git." -ForegroundColor Green
}

# --------------------------------------------------
# 4. Compare columns
# --------------------------------------------------

Write-Host ""
Write-Host "Checking columns..."

$ExpectedColumns = @()

foreach ($File in $TableFiles) {

    $Content = Get-Content $File.FullName -Raw

    $TableMatch = [regex]::Match(
        $Content,
        '(?i)CREATE\s+TABLE\s+(?:\[dbo\]\.)?\[?([A-Za-z0-9_]+)\]?'
    )

    if (-not $TableMatch.Success) {
        continue
    }

    $TableName = $TableMatch.Groups[1].Value

    $ColumnMatches = [regex]::Matches(
        $Content,
        '(?im)^\s*\[?([A-Za-z0-9_]+)\]?\s+' +
        '\[?([A-Za-z0-9_]+)\]?' +
        '(?:\(([^)]*)\))?\s+' +
        '(?:NOT\s+NULL|NULL|IDENTITY)'
    )

    foreach ($ColumnMatch in $ColumnMatches) {

        $ColumnName = $ColumnMatch.Groups[1].Value
        $DataType = $ColumnMatch.Groups[2].Value
        $Length = $ColumnMatch.Groups[3].Value

        if ($ColumnName -notmatch '^(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK)$') {

            $ExpectedColumns += [PSCustomObject]@{
                TableName = $TableName
                ColumnName = $ColumnName
                DataType = $DataType.ToLower()
                Length = $Length
            }
        }
    }
}

$ColumnQuery = @"
SELECT
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    CASE
        WHEN ty.name IN ('nvarchar', 'varchar', 'char', 'nchar')
            THEN CAST(c.max_length AS VARCHAR(20))
        ELSE ''
    END AS Length
FROM sys.tables t
INNER JOIN sys.columns c
    ON t.object_id = c.object_id
INNER JOIN sys.types ty
    ON c.user_type_id = ty.user_type_id
INNER JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = 'dbo'
ORDER BY t.name, c.column_id;
"@

$ActualColumns = @()

$ColumnOutput = Invoke-SqlQuery $ColumnQuery

foreach ($Line in $ColumnOutput) {

    if ([string]::IsNullOrWhiteSpace($Line)) {
        continue
    }

    $Parts = $Line.Trim() -split '\s+'

    if ($Parts.Count -ge 3) {

        $ActualColumns += [PSCustomObject]@{
            TableName = $Parts[0]
            ColumnName = $Parts[1]
            DataType = $Parts[2].ToLower()
            Length = if ($Parts.Count -ge 4) { $Parts[3] } else { "" }
        }
    }
}

foreach ($ExpectedColumn in $ExpectedColumns) {

    $ActualColumn = $ActualColumns |
        Where-Object {
            $_.TableName -eq $ExpectedColumn.TableName -and
            $_.ColumnName -eq $ExpectedColumn.ColumnName
        }

    if ($null -eq $ActualColumn) {

        $DriftDetected = $true

        Write-Host `
            "MISSING COLUMN: $($ExpectedColumn.TableName).$($ExpectedColumn.ColumnName)" `
            -ForegroundColor Red

        continue
    }

    if ($ActualColumn.DataType -ne $ExpectedColumn.DataType) {

        $DriftDetected = $true

        Write-Host `
            "DATA TYPE MISMATCH: $($ExpectedColumn.TableName).$($ExpectedColumn.ColumnName)" `
            -ForegroundColor Red

        Write-Host `
            "  Expected: $($ExpectedColumn.DataType)" `
            -ForegroundColor Yellow

        Write-Host `
            "  Actual:   $($ActualColumn.DataType)" `
            -ForegroundColor Yellow
    }
}

foreach ($ActualColumn in $ActualColumns) {

    $ExpectedColumn = $ExpectedColumns |
        Where-Object {
            $_.TableName -eq $ActualColumn.TableName -and
            $_.ColumnName -eq $ActualColumn.ColumnName
        }

    if ($null -eq $ExpectedColumn) {

        $DriftDetected = $true

        Write-Host `
            "UNEXPECTED COLUMN: $($ActualColumn.TableName).$($ActualColumn.ColumnName)" `
            -ForegroundColor Red
    }
}

# --------------------------------------------------
# 5. Check stored procedures
# --------------------------------------------------

Write-Host ""
Write-Host "Checking stored procedures..."

$ExpectedProcedures = @()

if (Test-Path $ProcedurePath) {

    $ProcedureFiles = Get-ChildItem $ProcedurePath -Filter "*.sql" |
        Sort-Object Name

    foreach ($File in $ProcedureFiles) {

        $Content = Get-Content $File.FullName -Raw

        $Match = [regex]::Match(
            $Content,
            '(?i)CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\s+(?:\[dbo\]\.)?\[?([A-Za-z0-9_]+)\]?'
        )

        if ($Match.Success) {
            $ExpectedProcedures += $Match.Groups[1].Value
        }
    }
}

$ProcedureQuery = @"
SELECT p.name
FROM sys.procedures p
INNER JOIN sys.schemas s
    ON p.schema_id = s.schema_id
WHERE s.name = 'dbo'
ORDER BY p.name;
"@

$ActualProcedures = @(Invoke-SqlQuery $ProcedureQuery |
    Where-Object { $_.Trim() -ne "" } |
    ForEach-Object { $_.Trim() })

foreach ($Procedure in $ExpectedProcedures) {

    if ($Procedure -notin $ActualProcedures) {

        $DriftDetected = $true

        Write-Host `
            "MISSING PROCEDURE: $Procedure" `
            -ForegroundColor Red
    }
}

# --------------------------------------------------
# 6. Final result
# --------------------------------------------------

Write-Host ""
Write-Host "========================================"

if ($DriftDetected) {

    Write-Host `
        "SCHEMA DRIFT DETECTED" `
        -ForegroundColor Red

    Write-Host "========================================"

    exit 1
}
else {

    Write-Host `
        "NO SCHEMA DRIFT DETECTED" `
        -ForegroundColor Green

    Write-Host "========================================"

    exit 0
}