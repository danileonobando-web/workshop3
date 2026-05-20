$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $projectRoot

Write-Host "Starting MySQL mirror for SQL Developer..."
docker compose up -d mysql

Write-Host "Waiting for MySQL..."
Start-Sleep -Seconds 25

Write-Host "Installing PyMySQL if needed..."
python -m pip install pymysql | Out-Host

Write-Host "Making MySQL authentication compatible with SQL Developer..."
docker exec daniela-mysql mysql -uroot -e "ALTER USER 'daniela'@'%' IDENTIFIED WITH mysql_native_password BY 'daniela123'; FLUSH PRIVILEGES;"

Write-Host "Syncing PostgreSQL data into MySQL..."
python .\scripts\sync_mysql_from_postgres.py

$connectionsPath = "C:\Users\Daniela\AppData\Roaming\SQL Developer\system23.1.1.345.2114\o.jdeveloper.db.connection\connections.json"
if (Test-Path -LiteralPath $connectionsPath) {
    $backupPath = "$connectionsPath.bak-workshop3"
    Copy-Item -LiteralPath $connectionsPath -Destination $backupPath -Force

    $json = Get-Content -LiteralPath $connectionsPath -Raw | ConvertFrom-Json
    $LegacyConnectionName = "Workshop3" + "_MySQL_Docker"
    $json.connections = @($json.connections | Where-Object { $_.name -ne $LegacyConnectionName })
    $exists = $false
    foreach ($connection in $json.connections) {
        if ($connection.name -eq "Daniela_Workshop3_MySQL") {
            $exists = $true
        }
    }

    if (-not $exists) {
        $newConnection = [pscustomobject]@{
            info = [pscustomobject]@{
                customUrl = "jdbc:mysql://localhost:3306/daniela_workshop3"
                NoPasswordConnection = "false"
                hostname = "localhost"
                driver = "com.mysql.jdbc.Driver"
                subtype = "MYSQL"
                port = "3306"
                SavePassword = "false"
                zeroDateTimeBehavior = "convertToNull"
                RaptorConnectionType = "MySQL"
                user = "daniela"
            }
            name = "Daniela_Workshop3_MySQL"
            type = "jdbc"
        }
        $json.connections += $newConnection
        $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $connectionsPath -Encoding UTF8
        Write-Host "Added SQL Developer connection: Daniela_Workshop3_MySQL"
    } else {
        Write-Host "SQL Developer connection already exists: Daniela_Workshop3_MySQL"
    }
}

$sqlDeveloper = "C:\Users\Daniela\Downloads\sqldeveloper-24.3.1.347.1826-x64 (1)\sqldeveloper\sqldeveloper.exe"
if (Test-Path -LiteralPath $sqlDeveloper) {
    Start-Process -FilePath $sqlDeveloper
    Write-Host "SQL Developer opened."
}

Write-Host "Connection values:"
Write-Host "Name: Daniela_Workshop3_MySQL"
Write-Host "Host: localhost"
Write-Host "Port: 3306"
Write-Host "Database: daniela_workshop3"
Write-Host "User: daniela"
Write-Host "Password: daniela123"
