import json
import os
import pickle
from datetime import date, datetime, timezone
from pathlib import Path

import pandas as pd
import psycopg2
from kafka import KafkaConsumer
from psycopg2.extras import Json


TOPIC_NAME = "happiness-predictions"
BOOTSTRAP_SERVERS = ["localhost:9092"]
BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "models" / "model.pkl"
if not MODEL_PATH.exists():
    MODEL_PATH = BASE_DIR / "model.pkl"
FEATURE_COLUMNS = ["gdp", "family", "health", "freedom", "generosity", "corruption"]
AUTO_OFFSET_RESET = os.getenv("KAFKA_AUTO_OFFSET_RESET", "latest")
CONSUMER_GROUP_ID = os.getenv("KAFKA_CONSUMER_GROUP_ID", "happiness-consumer-group")

DB_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", "5432")),
    "dbname": os.getenv("POSTGRES_DB", "daniela_workshop3"),
    "user": os.getenv("POSTGRES_USER", "daniela"),
    "password": os.getenv("POSTGRES_PASSWORD", "daniela123"),
}

REQUIRED_FIELDS = {
    "country": str,
    "year": int,
    "gdp": (int, float),
    "family": (int, float),
    "health": (int, float),
    "freedom": (int, float),
    "generosity": (int, float),
    "corruption": (int, float),
    "actual_happiness_score": (int, float),
}


def get_connection():
    return psycopg2.connect(**DB_CONFIG)


def ensure_tables(connection) -> None:
    sql_path = BASE_DIR / "sql" / "create_tables.sql"
    with sql_path.open("r", encoding="utf-8") as sql_file:
        with connection.cursor() as cursor:
            cursor.execute(sql_file.read())
    connection.commit()


def insert_raw_event(
    connection,
    raw_message: str,
    event_payload: dict | None,
    kafka_topic: str,
    kafka_partition: int,
    kafka_offset: int,
) -> int:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO raw_happiness_events (
                event_payload_text,
                event_payload,
                processing_status,
                kafka_topic,
                kafka_partition,
                kafka_offset
            )
            VALUES (%s, %s, 'RECEIVED', %s, %s, %s)
            RETURNING raw_event_id;
            """,
            (
                raw_message,
                Json(event_payload) if event_payload is not None else None,
                kafka_topic,
                kafka_partition,
                kafka_offset,
            ),
        )
        raw_event_id = cursor.fetchone()[0]
    connection.commit()
    return raw_event_id


def update_raw_status(connection, raw_event_id: int, status: str, error_message: str | None = None) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE raw_happiness_events
            SET processing_status = %s,
                error_message = %s,
                processed_at = CURRENT_TIMESTAMP
            WHERE raw_event_id = %s;
            """,
            (status, error_message, raw_event_id),
        )
    connection.commit()


def validate_event(event: dict) -> tuple[bool, str | None, str]:
    missing = [field for field in REQUIRED_FIELDS if field not in event]
    if missing:
        return False, f"Campos faltantes: {missing}", "INVALID_SCHEMA"

    for field, expected_type in REQUIRED_FIELDS.items():
        if not isinstance(event[field], expected_type):
            return False, f"Tipo invalido en {field}: {type(event[field]).__name__}", "INVALID_SCHEMA"

    if not 2015 <= int(event["year"]) <= 2019:
        return False, "El year debe estar entre 2015 y 2019", "INVALID_VALUES"

    for field in FEATURE_COLUMNS + ["actual_happiness_score"]:
        value = float(event[field])
        if value < 0:
            return False, f"Valor negativo no permitido en {field}", "INVALID_VALUES"

    if float(event["actual_happiness_score"]) > 10:
        return False, "actual_happiness_score debe estar en escala 0-10", "INVALID_VALUES"

    return True, None, "VALID"


def load_model():
    with MODEL_PATH.open("rb") as model_file:
        return pickle.load(model_file)


def upsert_country(connection, country_name: str) -> int:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO dim_country (country_name)
            VALUES (%s)
            ON CONFLICT (country_name) DO UPDATE
            SET country_name = EXCLUDED.country_name
            RETURNING country_id;
            """,
            (country_name,),
        )
        country_id = cursor.fetchone()[0]
    connection.commit()
    return country_id


def upsert_date(connection, year: int, timestamp: datetime) -> int:
    source_date = date(year, 1, 1)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO dim_date (full_date, year, month, day, quarter, month_name)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (full_date) DO UPDATE
            SET year = EXCLUDED.year
            RETURNING date_id;
            """,
            (
                source_date,
                year,
                source_date.month,
                source_date.day,
                1,
                "January",
            ),
        )
        date_id = cursor.fetchone()[0]
    connection.commit()
    return date_id


def insert_prediction(connection, raw_event_id: int, event: dict, predicted_score: float) -> None:
    prediction_timestamp = datetime.now(timezone.utc)
    country_id = upsert_country(connection, event["country"])
    date_id = upsert_date(connection, int(event["year"]), prediction_timestamp)
    actual_score = float(event["actual_happiness_score"])
    prediction_error = abs(actual_score - predicted_score)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO fact_predictions (
                raw_event_id,
                country_id,
                date_id,
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
                prediction_timestamp
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
            """,
            (
                raw_event_id,
                country_id,
                date_id,
                int(event["year"]),
                float(event["gdp"]),
                float(event["family"]),
                float(event["health"]),
                float(event["freedom"]),
                float(event["generosity"]),
                float(event["corruption"]),
                actual_score,
                predicted_score,
                prediction_error,
                prediction_timestamp,
            ),
        )
    connection.commit()


def predict(model, event: dict) -> float:
    features = pd.DataFrame([{column: float(event[column]) for column in FEATURE_COLUMNS}])
    return float(model.predict(features)[0])


def main() -> None:
    print("--- Iniciando consumidor de predicciones ---")
    model = load_model()

    connection = get_connection()
    ensure_tables(connection)

    consumer = KafkaConsumer(
        TOPIC_NAME,
        bootstrap_servers=BOOTSTRAP_SERVERS,
        auto_offset_reset=AUTO_OFFSET_RESET,
        enable_auto_commit=True,
        group_id=CONSUMER_GROUP_ID,
        api_version=(0, 10, 1),
    )

    print("Conectado a Kafka. Esperando eventos...")

    for message in consumer:
        raw_message = message.value.decode("utf-8")

        try:
            event = json.loads(raw_message)
        except json.JSONDecodeError as exc:
            raw_event_id = insert_raw_event(
                connection,
                raw_message,
                None,
                message.topic,
                message.partition,
                message.offset,
            )
            update_raw_status(connection, raw_event_id, "INVALID_SCHEMA", str(exc))
            print(f"Evento invalido raw_event_id={raw_event_id}: JSON invalido")
            continue

        raw_event_id = insert_raw_event(
            connection,
            raw_message,
            event,
            message.topic,
            message.partition,
            message.offset,
        )
        is_valid, validation_error, invalid_status = validate_event(event)

        if not is_valid:
            update_raw_status(connection, raw_event_id, invalid_status, validation_error)
            print(f"Evento invalido raw_event_id={raw_event_id}: {validation_error}")
            continue

        try:
            predicted_score = predict(model, event)
            insert_prediction(connection, raw_event_id, event, predicted_score)
            update_raw_status(connection, raw_event_id, "VALID")
            print(
                f"{event['country']} {event['year']} | "
                f"real={event['actual_happiness_score']:.3f} "
                f"predicho={predicted_score:.3f}"
            )
        except Exception as exc:
            update_raw_status(connection, raw_event_id, "PREDICTION_ERROR", str(exc))
            print(f"Error de prediccion raw_event_id={raw_event_id}: {exc}")


if __name__ == "__main__":
    main()
