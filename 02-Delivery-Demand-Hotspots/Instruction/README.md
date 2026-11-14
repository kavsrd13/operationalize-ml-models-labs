# Exercise 02: Delivery-demand hotspots

## Goal

Aggregate orders by location and explore geographic clusters. The result describes
demand concentrations and does not determine optimal warehouse sites.

## Fork and clone the course repository

Install Python 3.10 or 3.11, Git, Azure CLI, and a notebook editor. Sign in to GitHub in your browser, open [the course repository](https://github.com/kavsrd13/operationalize-ml-models-labs), select **Fork**, choose your account as owner, and select **Create fork**. Keep the default repository name and `main` branch.

Clone your fork from PowerShell, replacing `YOUR-GITHUB-USERNAME` with your account name:

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

- [`olist-delivery-demand-hotspots.ipynb`](../olist-delivery-demand-hotspots.ipynb)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Run

1. Use the local setup above and select **Python (Olist Azure ML)**.
2. Open `../olist-delivery-demand-hotspots.ipynb` and run cells in order.
3. Inspect ZIP-prefix coordinate cleaning. Count records before and after removing invalid coordinates.
4. Aggregate orders by location and inspect demand counts. Compare a high-demand and low-demand area.
5. Run clustering and view the static plot. Explain how cluster count changes the map; the result describes demand, not optimal warehouse placement.
6. If internet is available, display the Folium map. Its background tiles require network access; the static plots work offline.

See `ORIGINAL_README.md` for the source note.
