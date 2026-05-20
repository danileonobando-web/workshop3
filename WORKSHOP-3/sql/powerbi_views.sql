-- Power BI-ready analytical views.
-- These views are also included in create_tables.sql, but this file is useful
-- if you need to recreate only the dashboard layer.

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
