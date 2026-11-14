# Exercise 01: Olist EDA and feature engineering

## Goal

Understand the Olist tables and construct freight-cost features without target leakage.

## Fork and clone the course repository

Install Python 3.10 or 3.11, Git, Azure CLI, and a notebook editor. Sign in to GitHub in your browser, open [the course repository](https://github.com/kavsrd13/operationalize-ml-models-labs), select **Fork**, choose your account as owner, and select **Create fork**. Keep the default repository name and `main` branch.

Clone your fork from PowerShell, replacing `YOUR-GITHUB-USERNAME` with your own account name:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
git remote get-url origin
```

The last command must show your fork, not the instructor repository. If you already cloned your fork for another exercise, enter that folder instead of cloning again. You do not need `gh auth login` to clone a public fork. GitHub sign-in is needed to create the fork and push your changes.

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
