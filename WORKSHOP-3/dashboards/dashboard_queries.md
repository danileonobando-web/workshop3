# Dashboard and KPIs

The dashboard must connect to PostgreSQL database `daniela_workshop3`, not to CSV files.

Suggested visualizations:

1. Average prediction error
   - Source: `AVG(fact_predictions.prediction_error)`
   - Chart type: KPI card

2. Predictions by country
   - Source: `fact_predictions` joined with `dim_country`
   - Chart type: bar chart

3. Predicted vs actual score
   - Source: `actual_score` and `predicted_score` from `fact_predictions`
   - Chart type: scatter plot or line chart

4. Prediction trends over time
   - Source: `prediction_timestamp`, `predicted_score`, `prediction_error`
   - Chart type: time series

5. Event processing status
   - Source: `raw_happiness_events.processing_status`
   - Chart type: donut or stacked bar

The SQL for these KPIs is available in `sql/kpis.sql`. Power BI-ready views are available in `sql/powerbi_views.sql`, and validation checks are available in `sql/validation_queries.sql`.
