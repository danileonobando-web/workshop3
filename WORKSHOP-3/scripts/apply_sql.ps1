$ErrorActionPreference = "Stop"

$PostgresContainer = "daniela-postgres"
$DbUser = "daniela"
$DbName = "daniela_workshop3"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $projectRoot

Write-Host "Applying PostgreSQL schema and Power BI views..."

docker compose up -d postgres

Write-Host "Waiting for PostgreSQL..."
Start-Sleep -Seconds 8

docker exec -i $PostgresContainer psql `
  -U $DbUser `
  -d $DbName `
  -f /docker-entrypoint-initdb.d/create_tables.sql

Write-Host "SQL applied successfully."
Write-Host "Power BI can now connect to localhost:5432 / daniela_workshop3."
