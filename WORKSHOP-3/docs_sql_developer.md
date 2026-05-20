# SQL Developer Connection

This project uses PostgreSQL as the main database because the workshop suggests PostgreSQL.

To make the data visible in SQL Developer, the project also creates a MySQL mirror with the same analytical tables and views.

## Connection

Use the connection already added to SQL Developer:

```text
Name: Daniela_Workshop3_MySQL
Type: MySQL
Host: localhost
Port: 3306
Database: daniela_workshop3
User: daniela
Password: daniela123
```

## Tables

- `raw_happiness_events`
- `dim_country`
- `dim_date`
- `fact_predictions`

## Views

- `dim_raw_event`
- `vw_prediction_details`
- `pbi_predictions_detail`
- `pbi_country_summary`
- `pbi_year_summary`
- `pbi_kpi_summary`

## Useful Queries

Open this file in SQL Developer:

```text
sql/sql_developer_queries.sql
```

## Refresh MySQL Mirror

If the Kafka/PostgreSQL data changes, run:

```powershell
.\scripts\sync_mysql_from_postgres.py
```

Or run the full population script:

```powershell
.\scripts\populate_powerbi_data.ps1
```
