"""Train a lag-one Delhi temperature model in an Azure ML command job."""

import argparse
from pathlib import Path

import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


COLUMNS = ["meantemp", "humidity", "wind_speed", "meanpressure"]
FEATURES = [f"{column}_lag1" for column in COLUMNS]


def prepare(train_path: Path, test_path: Path):
    train = pd.read_csv(train_path)
    test = pd.read_csv(test_path)
    cutoff = pd.to_datetime(test["date"]).min()
    data = pd.concat([train, test], ignore_index=True)
    data["date"] = pd.to_datetime(data["date"])
    data = data.sort_values("date").reset_index(drop=True)
    for column in COLUMNS:
        data[f"{column}_lag1"] = data[column].shift(1)
    data = data.dropna(subset=FEATURES + ["meantemp"])
    return data[data["date"] < cutoff], data[data["date"] >= cutoff]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--train", type=Path, required=True)
    parser.add_argument("--test", type=Path, required=True)
    args = parser.parse_args()
    train, test = prepare(args.train, args.test)
    model = Pipeline([("scaler", StandardScaler()), ("ridge", Ridge(alpha=1.0))])
    with mlflow.start_run():
        model.fit(train[FEATURES], train["meantemp"])
        prediction = model.predict(test[FEATURES])
        mae = mean_absolute_error(test["meantemp"], prediction)
        rmse = mean_squared_error(test["meantemp"], prediction) ** 0.5
        mlflow.log_metrics({"test_mae": float(mae), "test_rmse": float(rmse)})
        # Azure ML's tracking endpoint may not implement MLflow 3's logged-models API.
        # Save the MLflow package as a job output, which can still be registered.
        mlflow.sklearn.save_model(
            model, path="outputs/model", input_example=test[FEATURES].head(1),
            serialization_format=mlflow.sklearn.SERIALIZATION_FORMAT_CLOUDPICKLE,
        )
        print(f"test_mae={mae:.4f} test_rmse={rmse:.4f}")


if __name__ == "__main__":
    main()
