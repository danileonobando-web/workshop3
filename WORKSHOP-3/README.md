# Workshop 3: Streaming ETL with Apache Kafka and Machine Learning

This project implements a streaming ETL pipeline for the World Happiness datasets from 2015 to 2019. The pipeline harmonizes heterogeneous CSV schemas, trains a regression model to predict happiness score, streams events through Apache Kafka, validates incoming messages, stores raw events for traceability, generates real-time predictions, and stores analytical results in PostgreSQL.

## Architecture

Offline process:

1. Load historical CSV files from 2015 to 2019.
2. Analyze schema differences, missing values, duplicated records, and data types.
3. Harmonize columns into a unified analytical schema.
4. Train a regression model.
5. Serialize the model as `model.pkl`.

Streaming process:

1. `producer.py` reads the processed dataset `data_final_limpio.csv` and sends one JSON event at a time to Kafka topic `happiness-predictions`.
2. `consumer.py` receives each event from Kafka.
3. The original event is stored first in `raw_happiness_events`.
4. The event schema and values are validated.
5. Valid events are passed to the trained model.
6. Prediction results are stored in `fact_predictions`.
7. KPIs are queried from PostgreSQL for dashboarding.

## Unified Schema

The datasets use different column names across years. For example:

- `Happiness Score`, `Happiness.Score`, and `Score` become `actual_happiness_score`.
- `Economy (GDP per Capita)`, `Economy..GDP.per.Capita.`, and `GDP per capita` become `gdp`.
- `Family` and `Social support` become `family`.
- `Health (Life Expectancy)`, `Health..Life.Expectancy.`, and `Healthy life expectancy` become `health`.
- `Trust (Government Corruption)`, `Trust..Government.Corruption.`, and `Perceptions of corruption` become `corruption`.

Final event schema:

```json
{
  "country": "Colombia",
  "year": 2019,
  "gdp": 1.2,
  "family": 0.8,
  "health": 0.9,
  "freedom": 0.6,
  "generosity": 0.3,
  "corruption": 0.1,
  "actual_happiness_score": 6.2
}
```

## Cleaning Decisions

- Column names were standardized to lowercase snake case.
- Numeric columns were converted with `pd.to_numeric`.
- Rows with missing values in required model features were removed.
- Duplicate records were dropped after harmonization.
- The target variable is `actual_happiness_score`.

These decisions keep the streaming schema consistent and avoid prediction errors caused by missing or incompatible fields.

## Feature Engineering

Selected model features:

- `gdp`
- `family`
- `health`
- `freedom`
- `generosity`
- `corruption`

These variables are available across all five years after harmonization and are conceptually related to happiness score. Rank, confidence intervals, standard error, and dystopia residual were excluded to avoid target leakage or inconsistent availability across years.

## Machine Learning

The training script `train_model.py` uses a `RandomForestRegressor` when scikit-learn is available. If the local environment does not have scikit-learn installed, it falls back to a simple linear regression artifact so the pipeline remains reproducible.

Metrics generated:

- MAE
- RMSE
- R2

The trained model is saved as `model.pkl`, and metrics are saved in `model_metrics.csv`.

## Kafka Pipeline

Required topic:

```text
happiness-predictions
```

Producer:

```bash
python producer.py
```

Consumer:

```bash
python consumer.py
```

The consumer handles invalid records without crashing. Invalid events are stored in `raw_happiness_events` and marked with statuses such as `INVALID_SCHEMA`, `INVALID_VALUES`, or `PREDICTION_ERROR`.

## Database Schema

Main tables:

- `raw_happiness_events`: stores the original Kafka event exactly as received.
- `dim_country`: country dimension.
- `dim_date`: date/year dimension.
- `fact_predictions`: stores actual score, predicted score, prediction error, timestamp, and link to the raw event.
- `dim_raw_event`: view over raw events for analytical traceability.

SQL scripts:

- `sql/create_tables.sql`
- `sql/kpis.sql`
- `sql/powerbi_views.sql`
- `sql/mysql_create_tables.sql`
- `sql/sql_developer_queries.sql`
- `sql/validation_queries.sql`
- `sql/reset_database.sql`

## Dashboard

The dashboard must connect directly to PostgreSQL, not CSV files.

Required KPIs:

1. Average prediction error.
2. Predictions by country.
3. Predicted vs actual score.
4. Prediction trends over time.

Suggested dashboard notes and queries are in `dashboards/dashboard_queries.md`.

Power BI assets:

- `dashboards/powerbi_build_guide.md`: step-by-step dashboard construction guide.
- `dashboards/powerbi_measures.dax`: DAX measures for cards and visuals.
- `dashboards/powerbi_theme.json`: visual theme to import in Power BI.
- `dashboards/powerbi_native_queries.sql`: optional native SQL queries for Power BI.
- `dashboards/happiness_postgres.pbids`: Power BI data source shortcut for PostgreSQL.
- `dashboards/render_powerbi_previews.py`: renders dashboard screenshots from PostgreSQL.

SQL Developer:

- Main workshop database: PostgreSQL in Docker.
- SQL Developer mirror: MySQL in Docker.
- Connection name: `Daniela_Workshop3_MySQL`.
- Connection details are documented in `docs_sql_developer.md`.

## Execution Instructions

Install dependencies:

```bash
python -m pip install -r requirements.txt
```

Train the model:

```bash
python train_model.py
```

Start Kafka and PostgreSQL:

```bash
docker compose up -d
```

Run the consumer in one terminal:

```bash
python consumer.py
```

Run the producer in another terminal:

```bash
python producer.py
```

Or run the complete local demo from PowerShell:

```powershell
.\scripts\run_streaming_demo.ps1
```

Populate PostgreSQL specifically for Power BI:

```powershell
.\scripts\populate_powerbi_data.ps1
```

Apply or refresh only the SQL layer:

```powershell
.\scripts\apply_sql.ps1
```

Open Power BI Desktop:

```powershell
.\scripts\open_powerbi.ps1
```

Stop services:

```bash
docker compose down
```

Optional SQL utilities:

- Run `sql/kpis.sql` to get the dashboard metrics.
- Run `sql/validation_queries.sql` to verify row counts, invalid events, and traceability.
- Run `sql/reset_database.sql` only when you want to clear the database and stream the events again.

## Repository Contents

- `2015.csv` to `2019.csv`: original datasets.
- `eda.ipynb`: exploratory analysis notebook.
- `train_model.py`: batch ETL and model training script.
- `producer.py`: Kafka producer.
- `consumer.py`: Kafka consumer with validation, raw storage, and inference.
- `model.pkl`: serialized model.
- `docker-compose.yml`: Kafka, Zookeeper, and PostgreSQL.
- `sql/`: database and KPI scripts.
- `dashboards/`: dashboard documentation.
- `requirements.txt`: Python dependencies.
