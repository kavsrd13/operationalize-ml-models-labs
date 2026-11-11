# Exercise 02: Delivery-demand hotspots

## Goal

Aggregate orders by location and explore geographic clusters. The result describes
demand concentrations and does not determine optimal warehouse sites.

## Start from a fresh clone

Ask the instructor for access to the private GitHub repository. Install Python 3.10 or 3.11, GitHub CLI, Azure CLI, and a notebook editor. From an empty working folder in PowerShell:

```powershell
gh auth login
gh repo clone kavsrd13/operationalize-ml-models-labs
Set-Location .\operationalize-ml-models-labs
```

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
