# Exercise 01: Olist EDA and feature engineering

## Goal

Understand the Olist tables and construct freight-cost features without target leakage.

## Fork and clone the public repository

Install Python 3.10 or 3.11, Git, Azure CLI, and a notebook editor. The public course repository can be inspected or cloned without a GitHub login:

```powershell
git clone https://github.com/kavsrd13/operationalize-ml-models-labs.git
```

To save your exercise work in your own GitHub account, sign in at [GitHub](https://github.com/), open [the course repository](https://github.com/kavsrd13/operationalize-ml-models-labs), select **Fork**, and then select **Create fork**. Clone your fork instead of the upstream repository:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
git remote add upstream https://github.com/kavsrd13/operationalize-ml-models-labs.git
git remote -v
```

No `gh auth login` command is needed for cloning. GitHub sign-in is required only to create the fork or push changes to it.

Run local setup; this lab does not create Azure resources:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure
```

Select the **Python (Olist Azure ML)** notebook kernel.

## Code files

The actual code for this exercise is here:

- [`olist-eda-feature-engineering.ipynb`](../olist-eda-feature-engineering.ipynb)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Run

1. Use the local setup above and select the **Python (Olist Azure ML)** kernel.
2. Open `../olist-eda-feature-engineering.ipynb` and run its cells from top to bottom.
3. Identify the nine input CSVs. Check join cardinality before interpreting rows: order items and orders have different grains.
4. Inspect freight target distribution, missing values, purchase dates, and the train/test time split. Explain why delivery timestamps cannot be checkout features.
5. Confirm the notebook writes processed data to this exercise's `outputs` folder. Open a few rows and compare them with the feature list used in exercise 03.

No Azure training job is submitted. See `ORIGINAL_README.md` for the source note.
