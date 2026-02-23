# EIA-ETL

Automated energy data visualizations for Minnesota, sourced from the EIA API and state generator databases. Outputs are published as a static GitHub Pages site.

## Project Structure

```
EIA-ETL/
├── run_all.R                # Master script — runs everything
├── index.html               # Tabbed website (copied to output/)
├── scripts/
│   ├── helpers.R            # Shared functions, theme, API key setup
│   ├── net_generation.R     # MN/US/Midwest generation by fuel
│   ├── energy_consumption.R # MN energy consumption by fuel
│   ├── natural_gas.R        # Henry Hub prices, gas volatility
│   ├── renewables.R         # Renewable consumption and generation
│   ├── renewables_and_coal.R# Coal trends, carbon intensity, transition
│   ├── reliability.R        # SAIDI/SAIFI reliability indices
│   ├── residential_commercial.R # Sector-level consumption
│   ├── electrical_system_losses.R # System losses vs 2030 goal
│   ├── solar.R              # Solar capacity (requires DuckDB)
│   ├── wind.R               # Wind capacity (requires DuckDB)
│   └── storage.R            # Storage capacity (requires DuckDB)
└── output/
    ├── index.html           # Browsable dashboard
    ├── plots/               # All PNG visualizations
    └── data/                # All CSV data exports
```

## Setup

### 1. One-time: store your EIA API key

```r
keyring::key_set("eia_api")
# Paste your key when prompted
```

### 2. One-time: install packages

```r
install.packages(c(
  "tidyverse", "jsonlite", "httr", "janitor", "ggrepel",
  "keyring", "here", "rvest", "rio", "lubridate", "zoo", "duckdb"
))
```

### 3. Database scripts (Solar, Wind, Storage)

These three scripts read from the shared DuckDB generator database. The default path is:

```
I:/Enrgy_div/SEO/CleanEnegyTechUnit/CET Projects/Data Repository/generator_database_shared/generator_database_dbt/dev.duckdb
```

To override, set the `GENERATOR_DB_PATH` environment variable before running:

```r
Sys.setenv(GENERATOR_DB_PATH = "path/to/your/dev.duckdb")
```

If you don't have database access, comment out the three database scripts in `run_all.R`.

## Running

Open the project in RStudio (or set your working directory to the project root), then:

```r
source("run_all.R")
```

This will:
1. Query all EIA API endpoints and scrape reliability tables
2. Generate all plots to `output/plots/`
3. Export all data to `output/data/`
4. Copy the tabbed website to `output/index.html`

## Publishing to GitHub Pages

After running the pipeline:

```bash
git add .
git commit -m "Update data $(date +%Y-%m-%d)"
git push
```

GitHub Settings → Pages → Deploy from branch `main`, folder `/ (root)`.

The site will be live at: **https://mn-eet.github.io/EIA-ETL/output/**

Individual plots are permanently addressable, e.g.:
```
https://mn-eet.github.io/EIA-ETL/output/plots/electricity_generation_mn.png
```

## Handoff Notes

- **API Key**: Each analyst needs to run `keyring::key_set("eia_api")` once on their machine
- **No user-specific paths**: All paths use `here()` relative to the project root
- **Database access**: Solar, wind, and storage require I: drive access to the DuckDB file
- **Reliability data**: Scraped from EIA HTML tables — structure changes may require updates to `reliability.R`
- **MROW data**: Hardcoded EPA data in `net_generation.R` (2021 values) — update manually when new data available
