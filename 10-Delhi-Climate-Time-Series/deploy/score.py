"""Serve the saved climate pipeline without Azure's generated MLflow script."""

import json
import os
from pathlib import Path

import cloudpickle
import pandas as pd


FEATURES = ["meantemp_lag1", "humidity_lag1", "wind_speed_lag1", "meanpressure_lag1"]


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
    if frame.columns.tolist() != FEATURES:
        raise ValueError(f"Expected columns {FEATURES}")
    frame = frame.apply(pd.to_numeric, errors="raise")
    if frame.isna().any().any():
        raise ValueError("Features must be numeric and non-null")
    return {"meantemp": [float(value) for value in model.predict(frame)]}
