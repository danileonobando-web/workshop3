-- Use only when you want to clear the workshop database and re-run the stream.
TRUNCATE TABLE fact_predictions RESTART IDENTITY CASCADE;
TRUNCATE TABLE dim_country RESTART IDENTITY CASCADE;
TRUNCATE TABLE dim_date RESTART IDENTITY CASCADE;
TRUNCATE TABLE raw_happiness_events RESTART IDENTITY CASCADE;
