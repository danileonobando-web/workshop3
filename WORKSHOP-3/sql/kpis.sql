-- KPI 1: Average prediction error
SELECT
    ROUND(AVG(prediction_error), 4) AS average_prediction_error
FROM fact_predictions;

-- KPI 2: Prediction volume and error by country
SELECT
    country_name,
    COUNT(*) AS total_predictions,
    ROUND(AVG(actual_score), 4) AS avg_actual_score,
    ROUND(AVG(predicted_score), 4) AS avg_predicted_score,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error
FROM vw_prediction_details
GROUP BY country_name
ORDER BY total_predictions DESC, avg_prediction_error DESC;

-- KPI 3: Predicted vs actual score detail
SELECT
    prediction_id,
    country_name,
    source_year,
    actual_score,
    predicted_score,
    prediction_error,
    prediction_timestamp
FROM vw_prediction_details
ORDER BY prediction_timestamp DESC;

-- KPI 4: Prediction trends over time
SELECT
    DATE_TRUNC('minute', prediction_timestamp) AS prediction_minute,
    COUNT(*) AS total_predictions,
    ROUND(AVG(actual_score), 4) AS avg_actual_score,
    ROUND(AVG(predicted_score), 4) AS avg_predicted_score,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error
FROM fact_predictions
GROUP BY DATE_TRUNC('minute', prediction_timestamp)
ORDER BY prediction_minute;

-- KPI 5: Raw event processing status
SELECT
    processing_status,
    total_events,
    percentage
FROM vw_raw_event_quality
ORDER BY total_events DESC;

-- KPI 6: Model performance by source year
SELECT
    source_year,
    COUNT(*) AS total_predictions,
    ROUND(AVG(prediction_error), 4) AS avg_prediction_error,
    ROUND(MIN(prediction_error), 4) AS min_prediction_error,
    ROUND(MAX(prediction_error), 4) AS max_prediction_error
FROM fact_predictions
GROUP BY source_year
ORDER BY source_year;

-- KPI 7: Top 10 highest prediction errors
SELECT
    country_name,
    source_year,
    actual_score,
    predicted_score,
    prediction_error,
    prediction_timestamp
FROM vw_prediction_details
ORDER BY prediction_error DESC
LIMIT 10;
