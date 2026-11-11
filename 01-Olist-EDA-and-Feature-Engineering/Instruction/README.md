# Exercise 01: Olist EDA and feature engineering

## Goal

Understand the Olist tables and construct freight-cost features without target leakage.

## Run

1. From the collection root run `python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure` if you only need local labs. Select the **Python (Olist Azure ML)** kernel installed by setup.
2. Open `../olist-eda-feature-engineering.ipynb` and run its cells from top to bottom.
3. Identify the nine input CSVs. Check join cardinality before interpreting rows: order items and orders have different grains.
4. Inspect freight target distribution, missing values, purchase dates, and the train/test time split. Explain why delivery timestamps cannot be checkout features.
5. Confirm the notebook writes processed data to this exercise's `outputs` folder. Open a few rows and compare them with the feature list used in exercise 03.

No Azure training job is submitted. See `ORIGINAL_README.md` for the source note.
