-- SQL Developer / MySQL validation queries.
-- Connection: Daniela_Workshop3_MySQL
-- Host: localhost
-- Port: 3306
-- Database: daniela_workshop3
-- User: daniela
-- Password: daniela123

SELECT COUNT(*) AS raw_events
FROM raw_happiness_events;

SELECT COUNT(*) AS predictions
FROM fact_predictions;

SELECT *
FROM pbi_kpi_summary;

SELECT *
FROM pbi_year_summary
ORDER BY source_year;

SELECT country_name, total_predictions, avg_prediction_error
FROM pbi_country_summary
ORDER BY total_predictions DESC, avg_prediction_error DESC
LIMIT 20;

SELECT prediction_id, raw_event_id, country_name, source_year,
       actual_score, predicted_score, prediction_error
FROM pbi_predictions_detail
ORDER BY prediction_error DESC
LIMIT 20;
