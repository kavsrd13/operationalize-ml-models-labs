import argparse
import os

import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, roc_auc_score
from sklearn.model_selection import train_test_split


FEATURE_COLUMNS = [
    "Pregnancies",
    "PlasmaGlucose",
    "DiastolicBloodPressure",
    "TricepsThickness",
    "SerumInsulin",
    "BMI",
    "DiabetesPedigree",
    "Age",
]
TARGET_COLUMN = "Diabetic"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--training_data", required=True, help="Path to diabetes.csv")
    parser.add_argument(
        "--model_output",
        required=True,
        help="Output folder path for MLflow model artifact",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    data = pd.read_csv(args.training_data)

    x = data[FEATURE_COLUMNS]
    y = data[TARGET_COLUMN]

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=0.2, random_state=42, stratify=y
    )

    model = LogisticRegression(max_iter=1000, solver="liblinear")
    model.fit(x_train, y_train)

    predictions = model.predict(x_test)
    probabilities = model.predict_proba(x_test)[:, 1]

    accuracy = accuracy_score(y_test, predictions)
    auc = roc_auc_score(y_test, probabilities)

    os.makedirs(args.model_output, exist_ok=True)

    mlflow.log_metric("accuracy", float(accuracy))
    mlflow.log_metric("auc", float(auc))
    mlflow.sklearn.save_model(sk_model=model, path=args.model_output)

    print(f"accuracy={accuracy:.4f}")
    print(f"auc={auc:.4f}")
    print(f"model_output={args.model_output}")


if __name__ == "__main__":
    main()
