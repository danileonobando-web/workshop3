-- Workshop 3 - Streaming ETL with Kafka and Machine Learning
-- Database: PostgreSQL
-- Purpose: store raw Kafka events, validated predictions, and analytical dimensions.

CREATE TABLE IF NOT EXISTS raw_happiness_events (
    raw_event_id BIGSERIAL PRIMARY KEY,
    event_payload_text TEXT NOT NULL,
    event_payload JSONB,
    processing_status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
    error_message TEXT,
    kafka_topic VARCHAR(100),
    kafka_partition INT,
    kafka_offset BIGINT,
    received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    CONSTRAINT chk_raw_processing_status CHECK (
        processing_status IN (
            'RECEIVED',
            'VALID',
            'INVALID_SCHEMA',
            'INVALID_VALUES',
            'PREDICTION_ERROR'
        )
    )
);

CREATE TABLE IF NOT EXISTS dim_country (
    country_id BIGSERIAL PRIMARY KEY,
    country_name VARCHAR(150) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_date (
    date_id BIGSERIAL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT NOT NULL,
    month INT NOT NULL,
    day INT NOT NULL,
    quarter INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_dim_date_month CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT chk_dim_date_day CHECK (day BETWEEN 1 AND 31),
    CONSTRAINT chk_dim_date_quarter CHECK (quarter BETWEEN 1 AND 4)
);

CREATE TABLE IF NOT EXISTS fact_predictions (
    prediction_id BIGSERIAL PRIMARY KEY,
    raw_event_id BIGINT NOT NULL UNIQUE REFERENCES raw_happiness_events(raw_event_id),
    country_id BIGINT NOT NULL REFERENCES dim_country(country_id),
    date_id BIGINT NOT NULL REFERENCES dim_date(date_id),
    source_year INT NOT NULL,
    gdp NUMERIC(10, 6) NOT NULL,
    family NUMERIC(10, 6) NOT NULL,
    health NUMERIC(10, 6) NOT NULL,
    freedom NUMERIC(10, 6) NOT NULL,
    generosity NUMERIC(10, 6) NOT NULL,
    corruption NUMERIC(10, 6) NOT NULL,
    actual_score NUMERIC(6, 3) NOT NULL,
    predicted_score NUMERIC(6, 3) NOT NULL,
    prediction_error NUMERIC(6, 3) NOT NULL,
    prediction_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fact_source_year CHECK (source_year BETWEEN 2015 AND 2019),
    CONSTRAINT chk_fact_actual_score CHECK (actual_score BETWEEN 0 AND 10),
    CONSTRAINT chk_fact_predicted_score CHECK (predicted_score BETWEEN 0 AND 10),
    CONSTRAINT chk_fact_prediction_error CHECK (prediction_error >= 0)
);

CREATE OR REPLACE VIEW dim_raw_event AS
SELECT
    raw_event_id,
    processing_status,
    error_message,
    kafka_topic,
    kafka_partition,
    kafka_offset,
    received_at,
    processed_at,
    event_payload_text,
    event_payload
FROM raw_happiness_events;

CREATE OR REPLACE VIEW vw_prediction_details AS
SELECT
    f.prediction_id,
    r.raw_event_id,
    c.country_name,
    d.full_date,
    d.year AS prediction_year,
    f.source_year,
    f.gdp,
    f.family,
    f.health,
    f.freedom,
    f.generosity,
    f.corruption,
    f.actual_score,
    f.predicted_score,
    f.prediction_error,
    f.prediction_timestamp,
    r.processing_status,
    r.event_payload
FROM fact_predictions f
JOIN raw_happiness_events r ON r.raw_event_id = f.raw_event_id
JOIN dim_country c ON c.country_id = f.country_id
JOIN dim_date d ON d.date_id = f.date_id;

CREATE OR REPLACE VIEW vw_raw_event_quality AS
SELECT
    processing_status,
    COUNT(*) AS total_events,
    ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS percentage
FROM raw_happiness_events
GROUP BY processing_status;

CREATE OR REPLACE VIEW pbi_predictions_detail AS
SELECT
    prediction_id,
    raw_event_id,
    country_name,
    full_date,
    prediction_year,
    source_year,
    gdp,
    family,
    health,
    freedom,
    generosity,
    corruption,
    actual_score,
    predicted_score,
    prediction_error,
    ABS(actual_score - predicted_score) AS absolute_error,
    CASE
        WHEN prediction_error <= 0.25 THEN 'Low error'
        WHEN prediction_error <= 0.75 THEN 'Medium error'
        ELSE 'High error'
    END AS error_band,
    prediction_timestamp,
    processing_status
FROM vw_prediction_details;

CREATE OR REPLACE VIEW pbi_country_summary AS
SELECT
    country_name,
    COUNT(*) AS total_predictions,
    ROUND(AVG(actual_score), 4) AS avg_actual_score,
    ROUND(AVG(predicted_score), 4) AS avg_predicted_score,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error,
    ROUND(MIN(prediction_error), 4) AS min_prediction_error,
    ROUND(MAX(prediction_error), 4) AS max_prediction_error
FROM vw_prediction_details
GROUP BY country_name;

CREATE OR REPLACE VIEW pbi_year_summary AS
SELECT
    source_year,
    COUNT(*) AS total_predictions,
    ROUND(AVG(actual_score), 4) AS avg_actual_score,
    ROUND(AVG(predicted_score), 4) AS avg_predicted_score,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error
FROM fact_predictions
GROUP BY source_year;

CREATE OR REPLACE VIEW pbi_prediction_trend AS
SELECT
    DATE_TRUNC('minute', prediction_timestamp) AS prediction_minute,
    COUNT(*) AS total_predictions,
    ROUND(AVG(actual_score), 4) AS avg_actual_score,
    ROUND(AVG(predicted_score), 4) AS avg_predicted_score,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error
FROM fact_predictions
GROUP BY DATE_TRUNC('minute', prediction_timestamp);

CREATE OR REPLACE VIEW pbi_event_quality AS
SELECT
    processing_status,
    total_events,
    percentage
FROM vw_raw_event_quality;

CREATE OR REPLACE VIEW pbi_kpi_summary AS
SELECT
    COUNT(*) AS total_predictions,
    ROUND(AVG(actual_score), 4) AS avg_actual_score,
    ROUND(AVG(predicted_score), 4) AS avg_predicted_score,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error,
    ROUND(MIN(prediction_error), 4) AS min_prediction_error,
    ROUND(MAX(prediction_error), 4) AS max_prediction_error
FROM fact_predictions;

CREATE INDEX IF NOT EXISTS idx_raw_happiness_events_status
    ON raw_happiness_events (processing_status);

CREATE INDEX IF NOT EXISTS idx_raw_happiness_events_received_at
    ON raw_happiness_events (received_at);

CREATE INDEX IF NOT EXISTS idx_raw_happiness_events_payload_gin
    ON raw_happiness_events USING GIN (event_payload);

CREATE INDEX IF NOT EXISTS idx_dim_country_name
    ON dim_country (country_name);

CREATE INDEX IF NOT EXISTS idx_dim_date_year
    ON dim_date (year);

CREATE INDEX IF NOT EXISTS idx_fact_predictions_country
    ON fact_predictions (country_id);

CREATE INDEX IF NOT EXISTS idx_fact_predictions_date
    ON fact_predictions (date_id);

CREATE INDEX IF NOT EXISTS idx_fact_predictions_source_year
    ON fact_predictions (source_year);

CREATE INDEX IF NOT EXISTS idx_fact_predictions_timestamp
    ON fact_predictions (prediction_timestamp);
