$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$logsDir = Join-Path $projectRoot "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
Set-Location $projectRoot

$PostgresContainer = "daniela-postgres"
$DbUser = "daniela"
$DbName = "daniela_workshop3"

Write-Host "Starting Docker services..."
docker compose up -d

Write-Host "Waiting for Kafka and databases..."
Start-Sleep -Seconds 30

Write-Host "Recreating Kafka topic happiness-predictions..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic happiness-predictions 2>$null | Out-Null
Start-Sleep -Seconds 5
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic happiness-predictions --partitions 1 --replication-factor 1 | Out-Host

Write-Host "Applying SQL schema and Power BI views..."
docker exec -i $PostgresContainer psql `
  -U $DbUser `
  -d $DbName `
  -f /docker-entrypoint-initdb.d/create_tables.sql | Out-Host

Write-Host "Resetting dashboard tables..."
docker exec $PostgresContainer psql `
  -U $DbUser `
  -d $DbName `
  -c "TRUNCATE TABLE fact_predictions, dim_country, dim_date, raw_happiness_events RESTART IDENTITY CASCADE;" | Out-Host

Write-Host "Starting consumer..."
$env:KAFKA_AUTO_OFFSET_RESET = "earliest"
$env:KAFKA_CONSUMER_GROUP_ID = "happiness-consumer-group-powerbi-$([System.Guid]::NewGuid().ToString('N'))"
$consumerOut = Join-Path $logsDir "consumer.out.log"
$consumerErr = Join-Path $logsDir "consumer.err.log"
$consumer = Start-Process `
  -FilePath "python" `
  -ArgumentList "consumer.py" `
  -WorkingDirectory $projectRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $consumerOut `
  -RedirectStandardError $consumerErr `
  -PassThru

try {
  Start-Sleep -Seconds 12

  Write-Host "Running producer..."
  $env:STREAM_DELAY_SECONDS = "0.01"
  python producer.py *> (Join-Path $logsDir "producer.log")

  Write-Host "Waiting for predictions to reach PostgreSQL..."
  $expected = 781
  $actual = 0
  for ($i = 0; $i -lt 60; $i++) {
    $actual = [int](docker exec $PostgresContainer psql `
      -U $DbUser `
      -d $DbName `
      -t `
      -A `
      -c "SELECT COUNT(*) FROM fact_predictions;")

    if ($actual -ge $expected) {
      break
    }

    Start-Sleep -Seconds 2
  }

  Write-Host "Predictions in fact_predictions: $actual"
  docker exec $PostgresContainer psql `
    -U $DbUser `
    -d $DbName `
    -c "SELECT * FROM pbi_kpi_summary;" | Out-Host

  Write-Host "Syncing data into MySQL mirror for SQL Developer..."
  docker compose up -d mysql
  Start-Sleep -Seconds 10
  docker exec daniela-mysql mysql -uroot -e "ALTER USER 'daniela'@'%' IDENTIFIED WITH mysql_native_password BY 'daniela123'; FLUSH PRIVILEGES;"
  python .\scripts\sync_mysql_from_postgres.py
}
finally {
  if ($consumer -and -not $consumer.HasExited) {
    Stop-Process -Id $consumer.Id -Force
  }
}

Write-Host "Power BI data is ready. Connect to localhost:5432 / daniela_workshop3."
