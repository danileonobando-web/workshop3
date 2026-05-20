CREATE DATABASE IF NOT EXISTS daniela_workshop3;
USE daniela_workshop3;

CREATE TABLE IF NOT EXISTS raw_happiness_events (
    raw_event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_payload_text LONGTEXT NOT NULL,
    event_payload JSON NULL,
    processing_status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
    error_message TEXT,
    kafka_topic VARCHAR(100),
    kafka_partition INT,
    kafka_offset BIGINT,
    received_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS dim_country (
    country_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    country_name VARCHAR(150) NOT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_date (
    date_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT NOT NULL,
    month INT NOT NULL,
    day INT NOT NULL,
    quarter INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fact_predictions (
    prediction_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    raw_event_id BIGINT NOT NULL UNIQUE,
    country_id BIGINT NOT NULL,
    date_id BIGINT NOT NULL,
    source_year INT NOT NULL,
    gdp DECIMAL(10, 6) NOT NULL,
    family DECIMAL(10, 6) NOT NULL,
    health DECIMAL(10, 6) NOT NULL,
    freedom DECIMAL(10, 6) NOT NULL,
    generosity DECIMAL(10, 6) NOT NULL,
    corruption DECIMAL(10, 6) NOT NULL,
    actual_score DECIMAL(6, 3) NOT NULL,
    predicted_score DECIMAL(6, 3) NOT NULL,
    prediction_error DECIMAL(6, 3) NOT NULL,
    prediction_timestamp TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fact_raw_event FOREIGN KEY (raw_event_id) REFERENCES raw_happiness_events(raw_event_id),
    CONSTRAINT fk_fact_country FOREIGN KEY (country_id) REFERENCES dim_country(country_id),
    CONSTRAINT fk_fact_date FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
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
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error
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

CREATE OR REPLACE VIEW pbi_kpi_summary AS
SELECT
    COUNT(*) AS total_predictions,
    ROUND(AVG(actual_score), 4) AS avg_actual_score,
    ROUND(AVG(predicted_score), 4) AS avg_predicted_score,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error,
    ROUND(MIN(prediction_error), 4) AS min_prediction_error,
    ROUND(MAX(prediction_error), 4) AS max_prediction_error
FROM fact_predictions;
