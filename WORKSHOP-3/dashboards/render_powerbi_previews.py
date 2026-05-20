from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import pandas as pd
import psycopg2


BASE_DIR = Path(__file__).resolve().parent
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "daniela_workshop3",
    "user": "daniela",
    "password": "daniela123",
}

BLUE = "#2563EB"
GREEN = "#16A34A"
ORANGE = "#F97316"
RED = "#DC2626"
SLATE = "#0F172A"
MUTED = "#64748B"
BG = "#F8FAFC"


def read_sql(connection, query):
    return pd.read_sql_query(query, connection)


def style_axis(ax, title):
    ax.set_title(title, loc="left", fontsize=12, fontweight="bold", color=SLATE, pad=12)
    ax.grid(axis="y", color="#E2E8F0", linewidth=0.8)
    ax.set_facecolor("white")
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.tick_params(colors=MUTED, labelsize=9)


def draw_card(fig, left, bottom, width, height, title, value, color=BLUE):
    ax = fig.add_axes([left, bottom, width, height])
    ax.set_facecolor("white")
    ax.text(0.04, 0.72, title, fontsize=10, color=MUTED, transform=ax.transAxes)
    ax.text(0.04, 0.20, value, fontsize=22, fontweight="bold", color=color, transform=ax.transAxes)
    ax.set_xticks([])
    ax.set_yticks([])
    for spine in ax.spines.values():
        spine.set_color("#CBD5E1")
    return ax


def render_overview(connection):
    kpi = read_sql(connection, "SELECT * FROM pbi_kpi_summary").iloc[0]
    trend = read_sql(connection, "SELECT * FROM pbi_prediction_trend ORDER BY prediction_minute")
    countries = read_sql(
        connection,
        """
        SELECT country_name, total_predictions
        FROM pbi_country_summary
        ORDER BY total_predictions DESC, country_name
        LIMIT 10
        """,
    )
    quality = read_sql(connection, "SELECT * FROM pbi_event_quality ORDER BY total_events DESC")

    fig = plt.figure(figsize=(15, 8.5), facecolor=BG)
    fig.suptitle("Workshop 3 - Streaming ETL Dashboard", x=0.04, y=0.97, ha="left", fontsize=18, fontweight="bold", color=SLATE)

    draw_card(fig, 0.04, 0.78, 0.18, 0.13, "Total predictions", f"{int(kpi.total_predictions):,}", BLUE)
    draw_card(fig, 0.25, 0.78, 0.18, 0.13, "Avg prediction error", f"{kpi.avg_prediction_error:.3f}", ORANGE)
    draw_card(fig, 0.46, 0.78, 0.18, 0.13, "Avg actual score", f"{kpi.avg_actual_score:.3f}", GREEN)
    draw_card(fig, 0.67, 0.78, 0.18, 0.13, "Avg predicted score", f"{kpi.avg_predicted_score:.3f}", BLUE)

    ax1 = fig.add_axes([0.04, 0.43, 0.56, 0.27])
    style_axis(ax1, "Prediction error trend")
    ax1.plot(trend["prediction_minute"], trend["avg_prediction_error"], color=ORANGE, linewidth=2)
    ax1.set_ylabel("Avg error", color=MUTED)

    ax2 = fig.add_axes([0.66, 0.43, 0.29, 0.27])
    style_axis(ax2, "Raw event quality")
    ax2.pie(quality["total_events"], labels=quality["processing_status"], autopct="%1.0f%%", colors=[GREEN, RED, ORANGE], textprops={"fontsize": 9})

    ax3 = fig.add_axes([0.04, 0.08, 0.91, 0.27])
    style_axis(ax3, "Predictions by country - top 10")
    ax3.bar(countries["country_name"], countries["total_predictions"], color=BLUE)
    ax3.tick_params(axis="x", rotation=35)
    ax3.set_ylabel("Predictions", color=MUTED)

    fig.savefig(BASE_DIR / "powerbi_page_1_overview.png", dpi=160, bbox_inches="tight")
    plt.close(fig)


def render_model_performance(connection):
    detail = read_sql(connection, "SELECT * FROM pbi_predictions_detail")
    years = read_sql(connection, "SELECT * FROM pbi_year_summary ORDER BY source_year")
    high_errors = read_sql(
        connection,
        """
        SELECT country_name, source_year, actual_score, predicted_score, prediction_error
        FROM pbi_predictions_detail
        ORDER BY prediction_error DESC
        LIMIT 12
        """,
    )

    fig = plt.figure(figsize=(15, 8.5), facecolor=BG)
    fig.suptitle("Model Performance", x=0.04, y=0.97, ha="left", fontsize=18, fontweight="bold", color=SLATE)

    ax1 = fig.add_axes([0.05, 0.47, 0.44, 0.40])
    style_axis(ax1, "Predicted vs actual score")
    colors = detail["error_band"].map({"Low error": GREEN, "Medium error": ORANGE, "High error": RED}).fillna(BLUE)
    ax1.scatter(detail["actual_score"], detail["predicted_score"], c=colors, alpha=0.70, s=28)
    min_score = min(detail["actual_score"].min(), detail["predicted_score"].min())
    max_score = max(detail["actual_score"].max(), detail["predicted_score"].max())
    ax1.plot([min_score, max_score], [min_score, max_score], color=MUTED, linestyle="--", linewidth=1)
    ax1.set_xlabel("Actual score", color=MUTED)
    ax1.set_ylabel("Predicted score", color=MUTED)

    ax2 = fig.add_axes([0.57, 0.47, 0.36, 0.40])
    style_axis(ax2, "Average prediction error by year")
    ax2.bar(years["source_year"].astype(str), years["avg_prediction_error"], color=ORANGE)
    ax2.set_ylabel("Avg error", color=MUTED)

    ax3 = fig.add_axes([0.05, 0.08, 0.88, 0.28])
    ax3.set_facecolor("white")
    ax3.axis("off")
    table_data = high_errors.round(3).values
    table = ax3.table(cellText=table_data, colLabels=high_errors.columns, loc="center", cellLoc="left", colLoc="left")
    table.auto_set_font_size(False)
    table.set_fontsize(8)
    table.scale(1, 1.35)
    ax3.set_title("Top prediction errors", loc="left", fontsize=12, fontweight="bold", color=SLATE, pad=12)

    fig.savefig(BASE_DIR / "powerbi_page_2_model_performance.png", dpi=160, bbox_inches="tight")
    plt.close(fig)


def render_data_quality(connection):
    quality = read_sql(connection, "SELECT * FROM pbi_event_quality ORDER BY total_events DESC")
    detail = read_sql(
        connection,
        """
        SELECT prediction_id, raw_event_id, country_name, source_year, processing_status, prediction_error
        FROM pbi_predictions_detail
        ORDER BY prediction_id DESC
        LIMIT 15
        """,
    )
    bands = read_sql(
        connection,
        """
        SELECT error_band, COUNT(*) AS total_predictions
        FROM pbi_predictions_detail
        GROUP BY error_band
        ORDER BY total_predictions DESC
        """,
    )

    fig = plt.figure(figsize=(15, 8.5), facecolor=BG)
    fig.suptitle("Data Quality and Traceability", x=0.04, y=0.97, ha="left", fontsize=18, fontweight="bold", color=SLATE)

    ax1 = fig.add_axes([0.05, 0.50, 0.35, 0.36])
    style_axis(ax1, "Processing status")
    ax1.bar(quality["processing_status"], quality["total_events"], color=GREEN)
    ax1.set_ylabel("Events", color=MUTED)

    ax2 = fig.add_axes([0.50, 0.50, 0.38, 0.36])
    style_axis(ax2, "Prediction error bands")
    palette = {"Low error": GREEN, "Medium error": ORANGE, "High error": RED}
    ax2.bar(bands["error_band"], bands["total_predictions"], color=[palette.get(x, BLUE) for x in bands["error_band"]])
    ax2.set_ylabel("Predictions", color=MUTED)

    ax3 = fig.add_axes([0.05, 0.08, 0.88, 0.30])
    ax3.set_facecolor("white")
    ax3.axis("off")
    table_data = detail.round(3).values
    table = ax3.table(cellText=table_data, colLabels=detail.columns, loc="center", cellLoc="left", colLoc="left")
    table.auto_set_font_size(False)
    table.set_fontsize(8)
    table.scale(1, 1.35)
    ax3.set_title("Latest predictions with raw event id", loc="left", fontsize=12, fontweight="bold", color=SLATE, pad=12)

    fig.savefig(BASE_DIR / "powerbi_page_3_data_quality.png", dpi=160, bbox_inches="tight")
    plt.close(fig)


def main():
    with psycopg2.connect(**DB_CONFIG) as connection:
        render_overview(connection)
        render_model_performance(connection)
        render_data_quality(connection)


if __name__ == "__main__":
    main()
