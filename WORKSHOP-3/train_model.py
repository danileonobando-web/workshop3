from pathlib import Path
import pickle

import numpy as np
import pandas as pd

from model_artifact import LinearRegressionArtifact


BASE_DIR = Path(__file__).resolve().parent
FEATURE_COLUMNS = ["gdp", "family", "health", "freedom", "generosity", "corruption"]
TARGET_COLUMN = "actual_happiness_score"

COLUMN_MAP = {
    "Country": "country",
    "Country or region": "country",
    "Happiness Score": TARGET_COLUMN,
    "Happiness.Score": TARGET_COLUMN,
    "Score": TARGET_COLUMN,
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


def build_unified_dataset() -> pd.DataFrame:
    frames = []
    for year in range(2015, 2020):
        raw_path = BASE_DIR / "data" / "raw" / f"{year}.csv"
        source_path = raw_path if raw_path.exists() else BASE_DIR / f"{year}.csv"
        df = pd.read_csv(source_path).rename(columns=COLUMN_MAP)
        df["year"] = year
        selected_columns = ["country", "year", *FEATURE_COLUMNS, TARGET_COLUMN]
        frames.append(df[selected_columns])

    data = pd.concat(frames, ignore_index=True)
    numeric_columns = ["year", *FEATURE_COLUMNS, TARGET_COLUMN]
    data[numeric_columns] = data[numeric_columns].apply(pd.to_numeric, errors="coerce")
    data = data.dropna(subset=["country", *numeric_columns]).drop_duplicates()
    return data


def main() -> None:
    data = build_unified_dataset()
    processed_dir = BASE_DIR / "data" / "processed"
    processed_dir.mkdir(parents=True, exist_ok=True)
    processed_path = processed_dir / "data_final_limpio.csv"
    data.to_csv(processed_path, index=False)
    data.to_csv(BASE_DIR / "data_final_limpio.csv", index=False)

    x = data[FEATURE_COLUMNS]
    y = data[TARGET_COLUMN]
    split_index = int(len(data) * 0.70)
    x_train, x_test = x.iloc[:split_index], x.iloc[split_index:]
    y_train, y_test = y.iloc[:split_index], y.iloc[split_index:]

    try:
        from sklearn.ensemble import RandomForestRegressor
        from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

        model = RandomForestRegressor(n_estimators=120, random_state=42)
        model.fit(x_train, y_train)
        predictions = model.predict(x_test)
        model_type = "RandomForestRegressor"
    except ImportError:
        train_matrix = np.c_[np.ones(len(x_train)), x_train.to_numpy(dtype=float)]
        weights = np.linalg.lstsq(train_matrix, y_train.to_numpy(dtype=float), rcond=None)[0]
        model = LinearRegressionArtifact(FEATURE_COLUMNS, weights[1:], weights[0])
        predictions = model.predict(x_test)
        model_type = "LinearRegressionArtifact"

        def mean_absolute_error(actual, predicted):
            return float(np.mean(np.abs(np.array(actual) - np.array(predicted))))

        def r2_score(actual, predicted):
            actual = np.array(actual, dtype=float)
            predicted = np.array(predicted, dtype=float)
            residual_sum = np.sum((actual - predicted) ** 2)
            total_sum = np.sum((actual - np.mean(actual)) ** 2)
            return float(1 - residual_sum / total_sum)

        def mean_squared_error(actual, predicted):
            return float(np.mean((np.array(actual) - np.array(predicted)) ** 2))

    mae = mean_absolute_error(y_test, predictions)
    rmse = mean_squared_error(y_test, predictions) ** 0.5
    r2 = r2_score(y_test, predictions)

    models_dir = BASE_DIR / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    with (models_dir / "model.pkl").open("wb") as model_file:
        pickle.dump(model, model_file)
    with (BASE_DIR / "model.pkl").open("wb") as model_file:
        pickle.dump(model, model_file)

    metrics = pd.DataFrame(
        [
            {
                "model_type": model_type,
                "mae": mae,
                "rmse": rmse,
                "r2": r2,
                "rows": len(data),
                "features": ",".join(FEATURE_COLUMNS),
            }
        ]
    )
    metrics.to_csv(BASE_DIR / "model_metrics.csv", index=False)

    print(f"Dataset limpio guardado en {processed_path}")
    print(f"Modelo guardado en {BASE_DIR / 'model.pkl'}")
    print(f"MAE={mae:.4f} RMSE={rmse:.4f} R2={r2:.4f}")


if __name__ == "__main__":
    main()
