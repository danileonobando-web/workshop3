import json

import psycopg2
import pymysql


POSTGRES = {
    "host": "localhost",
    "port": 5432,
    "dbname": "daniela_workshop3",
    "user": "daniela",
    "password": "daniela123",
}

MYSQL = {
    "host": "localhost",
    "port": 3306,
    "database": "daniela_workshop3",
    "user": "daniela",
    "password": "daniela123",
    "charset": "utf8mb4",
    "autocommit": False,
}


def fetch_all(pg_cursor, query):
    pg_cursor.execute(query)
    return pg_cursor.fetchall()


def main():
    pg = psycopg2.connect(**POSTGRES)
    my = pymysql.connect(**MYSQL)

    with pg, my:
        pg_cursor = pg.cursor()
        my_cursor = my.cursor()

        my_cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
        for table in ["fact_predictions", "dim_country", "dim_date", "raw_happiness_events"]:
            my_cursor.execute(f"TRUNCATE TABLE {table}")
        my_cursor.execute("SET FOREIGN_KEY_CHECKS = 1")

        raw_rows = fetch_all(
            pg_cursor,
            """
            SELECT raw_event_id, event_payload_text, event_payload::text, processing_status,
                   error_message, kafka_topic, kafka_partition, kafka_offset,
                   received_at, processed_at
            FROM raw_happiness_events
            ORDER BY raw_event_id
            """,
        )
        my_cursor.executemany(
            """
            INSERT INTO raw_happiness_events (
                raw_event_id, event_payload_text, event_payload, processing_status,
                error_message, kafka_topic, kafka_partition, kafka_offset,
                received_at, processed_at
            )
            VALUES (%s, %s, CAST(%s AS JSON), %s, %s, %s, %s, %s, %s, %s)
            """,
            raw_rows,
        )

        country_rows = fetch_all(
            pg_cursor,
            "SELECT country_id, country_name, created_at FROM dim_country ORDER BY country_id",
        )
        my_cursor.executemany(
            "INSERT INTO dim_country (country_id, country_name, created_at) VALUES (%s, %s, %s)",
            country_rows,
        )

        date_rows = fetch_all(
            pg_cursor,
            """
            SELECT date_id, full_date, year, month, day, quarter, month_name, created_at
            FROM dim_date
            ORDER BY date_id
            """,
        )
        my_cursor.executemany(
            """
            INSERT INTO dim_date (date_id, full_date, year, month, day, quarter, month_name, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            date_rows,
        )

        fact_rows = fetch_all(
            pg_cursor,
            """
            SELECT prediction_id, raw_event_id, country_id, date_id, source_year,
                   gdp, family, health, freedom, generosity, corruption,
                   actual_score, predicted_score, prediction_error, prediction_timestamp
            FROM fact_predictions
            ORDER BY prediction_id
            """,
        )
        my_cursor.executemany(
            """
            INSERT INTO fact_predictions (
                prediction_id, raw_event_id, country_id, date_id, source_year,
                gdp, family, health, freedom, generosity, corruption,
                actual_score, predicted_score, prediction_error, prediction_timestamp
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            fact_rows,
        )

        my.commit()
        print(json.dumps({"raw_events": len(raw_rows), "predictions": len(fact_rows)}, indent=2))


if __name__ == "__main__":
    main()
