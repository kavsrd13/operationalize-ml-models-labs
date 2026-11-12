# Exercise 02: Delivery-demand hotspots

## Goal

Aggregate orders by location and explore geographic clusters. The result describes
demand concentrations and does not determine optimal warehouse sites.

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
