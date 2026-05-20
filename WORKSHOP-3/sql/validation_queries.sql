-- Validate row counts in the streaming database.
SELECT 'raw_happiness_events' AS table_name, COUNT(*) AS rows FROM raw_happiness_events
UNION ALL
SELECT 'dim_country' AS table_name, COUNT(*) AS rows FROM dim_country
UNION ALL
SELECT 'dim_date' AS table_name, COUNT(*) AS rows FROM dim_date
UNION ALL
SELECT 'fact_predictions' AS table_name, COUNT(*) AS rows FROM fact_predictions;

-- Check that every valid raw event has one prediction.
SELECT
    COUNT(*) AS valid_events_without_prediction
FROM raw_happiness_events r
LEFT JOIN fact_predictions f ON f.raw_event_id = r.raw_event_id
WHERE r.processing_status = 'VALID'
  AND f.prediction_id IS NULL;

-- Check invalid records and their error messages.
SELECT
    raw_event_id,
    processing_status,
    error_message,
    received_at,
    event_payload_text
FROM raw_happiness_events
WHERE processing_status <> 'VALID'
ORDER BY received_at DESC;

-- Check prediction traceability back to the exact original event.
SELECT
    f.prediction_id,
    f.raw_event_id,
    r.event_payload_text,
    f.actual_score,
    f.predicted_score,
    f.prediction_error
FROM fact_predictions f
JOIN raw_happiness_events r ON r.raw_event_id = f.raw_event_id
ORDER BY f.prediction_id DESC
LIMIT 20;
