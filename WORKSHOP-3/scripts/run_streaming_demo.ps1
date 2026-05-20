$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $projectRoot

$PostgresContainer = "daniela-postgres"
$DbUser = "daniela"
$DbName = "daniela_workshop3"

Write-Host "Starting Kafka, Zookeeper, and PostgreSQL..."
docker compose up -d

Write-Host "Waiting for services..."
Start-Sleep -Seconds 20

Write-Host "Recreating Kafka topic happiness-predictions..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic happiness-predictions 2>$null | Out-Null
Start-Sleep -Seconds 5
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic happiness-predictions --partitions 1 --replication-factor 1 | Out-Host

Write-Host "Applying SQL schema..."
docker exec -i $PostgresContainer psql `
  -U $DbUser `
  -d $DbName `
  -f /docker-entrypoint-initdb.d/create_tables.sql

Write-Host "Starting Kafka consumer in a new PowerShell window..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; `$env:KAFKA_AUTO_OFFSET_RESET='earliest'; python consumer.py"

Write-Host "Waiting for consumer connection..."
Start-Sleep -Seconds 8

Write-Host "Starting producer..."
$env:STREAM_DELAY_SECONDS = "0.05"
python producer.py

Write-Host "Streaming demo finished. Keep the consumer window open until it processes the events."
