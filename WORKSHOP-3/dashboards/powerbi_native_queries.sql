-- Use these native queries in Power BI if you prefer loading queries
-- instead of selecting views from the Navigator.

-- Executive KPI cards
SELECT * FROM pbi_kpi_summary;

-- Detailed prediction table and scatter plot
SELECT * FROM pbi_predictions_detail;

-- Country-level bar charts
SELECT * FROM pbi_country_summary;

-- Year-level model performance
SELECT * FROM pbi_year_summary;

-- Trend chart
SELECT * FROM pbi_prediction_trend;

-- Data quality chart
SELECT * FROM pbi_event_quality;
