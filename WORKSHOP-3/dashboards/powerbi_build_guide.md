# Power BI Dashboard - Workshop 3

## Conexion

Abre Power BI Desktop y conecta a PostgreSQL:

- Server: `localhost:5432`
- Database: `daniela_workshop3`
- User: `daniela`
- Password: `daniela123`
- Data connectivity mode: `Import` o `DirectQuery`

Vistas recomendadas para cargar:

- `pbi_predictions_detail`
- `pbi_country_summary`
- `pbi_year_summary`
- `pbi_prediction_trend`
- `pbi_event_quality`
- `pbi_kpi_summary`

Importa el tema desde:

```text
dashboards/powerbi_theme.json
```

Crea las medidas desde:

```text
dashboards/powerbi_measures.dax
```

## Pagina 1: Executive Overview

Visuales:

- Card: `Total Predictions`
- Card: `Average Prediction Error`
- Card: `Average Actual Score`
- Card: `Average Predicted Score`
- Card: `Valid Event Rate`
- Line chart: `prediction_minute` vs `avg_prediction_error` from `pbi_prediction_trend`
- Bar chart: `country_name` vs `total_predictions` from `pbi_country_summary`
- Donut chart: `processing_status` vs `total_events` from `pbi_event_quality`

## Pagina 2: Model Performance

Visuales:

- Scatter chart:
  - X axis: `actual_score`
  - Y axis: `predicted_score`
  - Legend: `error_band`
  - Details: `country_name`
- Column chart:
  - Axis: `source_year`
  - Values: `avg_prediction_error`
- Table:
  - `country_name`
  - `source_year`
  - `actual_score`
  - `predicted_score`
  - `prediction_error`
  - `prediction_timestamp`

## Pagina 3: Data Quality and Traceability

Visuales:

- Donut chart: `processing_status` vs `total_events`
- Table from `pbi_predictions_detail`:
  - `prediction_id`
  - `raw_event_id`
  - `country_name`
  - `source_year`
  - `processing_status`
  - `prediction_error`
- Bar chart:
  - Axis: `error_band`
  - Values: `Total Predictions`

## Filtros sugeridos

Agrega slicers para:

- `source_year`
- `country_name`
- `error_band`
- `processing_status`

## Notas para entrega

Exporta capturas de cada pagina y guardalas en esta carpeta:

```text
dashboards/
```

Name suggestions:

- `powerbi_page_1_overview.png`
- `powerbi_page_2_model_performance.png`
- `powerbi_page_3_data_quality.png`
