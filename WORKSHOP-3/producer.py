import json
import os
import time
from pathlib import Path

import pandas as pd
from kafka import KafkaProducer


TOPIC_NAME = "happiness-predictions"
BOOTSTRAP_SERVERS = ["localhost:9092"]
BASE_DIR = Path(__file__).resolve().parent
STREAM_DELAY_SECONDS = float(os.getenv("STREAM_DELAY_SECONDS", "0.1"))


COLUMN_MAP = {
    "Country": "country",
    "Country or region": "country",
    "Happiness Score": "actual_happiness_score",
    "Happiness.Score": "actual_happiness_score",
    "Score": "actual_happiness_score",
    "Economy (GDP per Capita)": "gdp",
    "Economy..GDP.per.Capita.": "gdp",
    "GDP per capita": "gdp",
    "Family": "family",
    "Social support": "family",
    "Health (Life Expectancy)": "health",
    "Health..Life.Expectancy.": "health",
    "Healthy life expectancy": "health",
    "Freedom": "freedom",
    "Freedom to make life choices": "freedom",
    "Trust (Government Corruption)": "corruption",
    "Trust..Government.Corruption.": "corruption",
    "Perceptions of corruption": "corruption",
    "Generosity": "generosity",
}

EVENT_COLUMNS = [
    "country",
    "year",
    "gdp",
    "family",
    "health",
    "freedom",
    "generosity",
    "corruption",
    "actual_happiness_score",
]


def load_happiness_events() -> pd.DataFrame:
    candidate_paths = [
        BASE_DIR / "data" / "streaming" / "happiness_events.csv",
        BASE_DIR / "data" / "processed" / "data_final_limpio.csv",
        BASE_DIR / "data_final_limpio.csv",
    ]
    processed_path = next((path for path in candidate_paths if path.exists()), None)

    if processed_path is not None:
        data = pd.read_csv(processed_path)
        missing = [column for column in EVENT_COLUMNS if column not in data.columns]
        if missing:
            raise ValueError(f"{processed_path.name} no contiene columnas requeridas: {missing}")

        numeric_columns = [column for column in EVENT_COLUMNS if column != "country"]
        data[numeric_columns] = data[numeric_columns].apply(pd.to_numeric, errors="coerce")
        return data.dropna(subset=EVENT_COLUMNS).reset_index(drop=True)[EVENT_COLUMNS]

    frames = []

    for year in range(2015, 2020):
        raw_path = BASE_DIR / "data" / "raw" / f"{year}.csv"
        path = raw_path if raw_path.exists() else BASE_DIR / f"{year}.csv"
        df = pd.read_csv(path)
        df = df.rename(columns=COLUMN_MAP)
        df["year"] = year

        missing = [column for column in EVENT_COLUMNS if column not in df.columns]
        if missing:
            raise ValueError(f"{path.name} no contiene columnas requeridas: {missing}")

        frames.append(df[EVENT_COLUMNS])

    data = pd.concat(frames, ignore_index=True)
    numeric_columns = [column for column in EVENT_COLUMNS if column != "country"]
    data[numeric_columns] = data[numeric_columns].apply(pd.to_numeric, errors="coerce")
    data = data.dropna(subset=EVENT_COLUMNS).reset_index(drop=True)
    return data


def build_producer() -> KafkaProducer:
    return KafkaProducer(
        bootstrap_servers=BOOTSTRAP_SERVERS,
        value_serializer=lambda value: json.dumps(value).encode("utf-8"),
        api_version=(0, 10, 1),
    )


def main() -> None:
    producer = build_producer()
    events = load_happiness_events()

    print(f"Enviando {len(events)} eventos al topic {TOPIC_NAME}...")

    for index, row in events.iterrows():
        event = {
            "country": str(row["country"]),
            "year": int(row["year"]),
            "gdp": float(row["gdp"]),
            "family": float(row["family"]),
            "health": float(row["health"]),
            "freedom": float(row["freedom"]),
            "generosity": float(row["generosity"]),
            "corruption": float(row["corruption"]),
            "actual_happiness_score": float(row["actual_happiness_score"]),
        }

        producer.send(TOPIC_NAME, value=event)
        print(
            f"Evento {index + 1}: {event['country']} {event['year']} "
            f"score real={event['actual_happiness_score']:.3f}"
        )
        time.sleep(STREAM_DELAY_SECONDS)

    producer.flush()
    producer.close()
    print("Streaming finalizado.")


if __name__ == "__main__":
    main()
