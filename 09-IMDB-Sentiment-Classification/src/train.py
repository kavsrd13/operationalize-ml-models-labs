"""Train the IMDB sentiment model in an Azure ML command job."""

import argparse
from pathlib import Path

import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, required=True)
    args = parser.parse_args()
    df = pd.read_csv(args.data, usecols=["review", "sentiment"]).dropna()
    X = df["review"].astype(str)
    y = df["sentiment"].astype(str).str.lower().str.strip().map({"negative": 0, "positive": 1})
    if y.isna().any():
        raise ValueError("Unexpected sentiment label")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y.astype(int), test_size=0.2, random_state=42, stratify=y
    )
    model = Pipeline([
        ("tfidf", TfidfVectorizer(stop_words="english", max_features=20000, ngram_range=(1, 2))),
        ("clf", LogisticRegression(max_iter=1000)),
    ])
    with mlflow.start_run():
        model.fit(X_train, y_train)
        accuracy = accuracy_score(y_test, model.predict(X_test))
        mlflow.log_metric("test_accuracy", float(accuracy))
        mlflow.sklearn.save_model(
            model, path="outputs/model", input_example=pd.DataFrame({"review": ["A great movie"]}),
            serialization_format=mlflow.sklearn.SERIALIZATION_FORMAT_CLOUDPICKLE,
        )
        print(f"test_accuracy={accuracy:.4f}")


if __name__ == "__main__":
    main()
