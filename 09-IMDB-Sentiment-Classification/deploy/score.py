"""Serve the saved sentiment pipeline without Azure's generated MLflow script."""

import json
import os
from pathlib import Path

import cloudpickle
import pandas as pd


def init():
    global model
    files = list(Path(os.environ["AZUREML_MODEL_DIR"]).rglob("model.pkl"))
    if len(files) != 1:
        raise ValueError(f"Expected one model.pkl, found {len(files)}")
    with files[0].open("rb") as stream:
        model = cloudpickle.load(stream)


def run(raw_data):
    body = json.loads(raw_data) if isinstance(raw_data, str) else raw_data
    data = body["input_data"]
    frame = pd.DataFrame(data["data"], columns=data["columns"])
    if frame.columns.tolist() != ["review"] or frame["review"].isna().any():
        raise ValueError("Provide a nonempty review column")
    predictions = model.predict(frame["review"].astype(str))
    return {"sentiment": ["positive" if int(value) == 1 else "negative" for value in predictions]}
