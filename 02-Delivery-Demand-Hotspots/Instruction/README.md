# Exercise 02: Delivery-demand hotspots

## Goal

Aggregate orders by location and explore geographic clusters. The result describes
demand concentrations and does not determine optimal warehouse sites.

## Run

1. Complete the local setup in exercise 00 (`--skip-azure` is sufficient for this lab) and select **Python (Olist Azure ML)**.
2. Open `../olist-delivery-demand-hotspots.ipynb` and run cells in order.
3. Inspect ZIP-prefix coordinate cleaning. Count records before and after removing invalid coordinates.
4. Aggregate orders by location and inspect demand counts. Compare a high-demand and low-demand area.
5. Run clustering and view the static plot. Explain how cluster count changes the map; the result describes demand, not optimal warehouse placement.
6. If internet is available, display the Folium map. Its background tiles require network access; the static plots work offline.

See `ORIGINAL_README.md` for the source note.
