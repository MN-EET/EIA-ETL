# EIA Data Viewer

An R Markdown dashboard that pulls energy data from the U.S. Energy Information Administration (EIA) API and internal databases, then generates interactive tables, downloadable charts, and Excel exports focused on Minnesota's energy landscape. The rendered HTML report is organized as a tabbed interface, with each tab covering a different energy topic.

## What It Does

The main file, `EIA_Data_Viewer.Rmd`, knits together 11 child R Markdown scripts into a single tabbed HTML document. Each tab pulls live data from the EIA API (or from an internal DuckDB database), processes it, and produces interactive data tables and `ggplot2` visualizations. Every chart and dataset includes a download button so users can export plots as `.png` files and data as `.xlsx` files directly from the rendered report.

### Tabs and Their Contents

**Net Generation** — Electricity generation mix for Minnesota, the U.S., and the Midwest (West North Central + East North Central census divisions). Includes bar charts of the most recent year's generation by fuel type, dumbbell charts comparing generation shares over a 15-year span, time-series trends for all fuel sources, and a comparison against EIA's separately published state-level spreadsheet for data verification.

**Renewables** — Renewable energy consumption versus total energy consumption in Minnesota (with a reference line for the 25% renewable goal), a breakdown of renewable electricity generation by source (wind, solar, hydro, biomass), and a Minnesota-vs-U.S. comparison of renewable electricity share over time.

**Renewables and Coal** — Minnesota-vs-U.S. coal generation trends, carbon intensity of electricity (metric tons CO₂ per MWh), monthly seasonal dispatch patterns for coal, and a 12-month rolling average showing the generation transition between coal, renewables, and natural gas.

**Solar** — Sourced from an internal DuckDB generator database rather than the EIA API. Shows cumulative solar capacity in Minnesota, annual solar installations broken out by type (community solar, utility-scale, other), and the share of total solar capacity by installation type.

**Wind** — Also sourced from the internal DuckDB generator database. Shows cumulative wind capacity and annual wind installations in Minnesota.

**Storage** — Cumulative battery/energy storage capacity in Minnesota, sourced from the internal DuckDB generator database.

**Natural Gas** — Monthly Henry Hub spot prices with annotated events (Russia's invasion of Ukraine, Winter Storm Uri), and a 12-month rolling average of natural gas's share of Minnesota electricity generation.

**Energy Consumption** — Minnesota's total energy consumption broken out by source (petroleum, natural gas, coal, renewables, nuclear, imports) as both absolute values and percent-of-total over time. Also includes a detailed breakdown of renewable energy consumption by sub-source (wind, solar, hydro, ethanol, biodiesel, wood/waste, geothermal) and a Minnesota-vs-U.S. comparison of renewable share of total consumption.

**Energy Losses** — Tracks electrical system energy losses (billion BTU) over time against a 2030 goal of reducing waste heat and waste electricity by 15% compared to 2005 levels.

**Residential and Commercial Consumption** — Energy consumption in the residential, commercial, and industrial sectors, with separate views for total energy, electricity only, natural gas only, and combined electricity-plus-gas.

**Reliability** — Scrapes SAIDI (System Average Interruption Duration Index) and SAIFI (System Average Interruption Frequency Index) tables from EIA's website. Compares Minnesota against the West North Central region and the U.S. national average, with and without major event days.

## Prerequisites

### R Packages

Install the following packages before running the report:

```r
install.packages(c(
  "tidyverse",
  "jsonlite",
  "httr",
  "janitor",
  "downloadthis",
  "data.table",
  "ggrepel",
  "writexl",
  "rio",
  "extrafont",
  "here",
  "keyring",
  "lubridate",
  "zoo",
  "readxl",
  "duckdb",
  "DT",
  "rvest",
  "rmarkdown"
))
```

### EIA API Key

Several tabs pull data from the EIA v2 API, which requires an API key. The code retrieves this key at runtime using the `keyring` package:

```r
eia_key <- key_get("eia_api")
```

Before your first run, store your key in your system keyring:

```r
library(keyring)
key_set("eia_api")
# You'll be prompted to enter your API key
```

You can get a free API key by registering at [https://www.eia.gov/opendata/register.php](https://www.eia.gov/opendata/register.php).

### DuckDB Generator Database

The **Solar**, **Wind**, and **Storage** tabs query a shared DuckDB database rather than the EIA API. The database path is defined at the top of each of those scripts in a variable called `db_path`. You will need to update this path to point to the location of the DuckDB file on your system. The database is expected to contain the following tables/views:

- `main.mart_combined__solar_capacity`
- `main.mart_total__wind_capacity`
- `main.mart_combined__storage_capacity`

### Fonts

Some charts specify Calibri as the font family. If Calibri is not available on your system, the charts will still render but may fall back to a default font. To register system fonts with R, run `extrafont::font_import()` once.

## How to Run

1. Clone or download the repository.
2. Make sure all 12 `.Rmd` files are in the expected directory structure. The main file (`EIA_Data_Viewer.Rmd`) uses `here::here()` to locate child scripts in a `scripts/` subfolder. Place the child `.Rmd` files accordingly:
   ```
   project_root/
   ├── EIA_Data_Viewer.Rmd
   └── scripts/
       ├── Net Generation.Rmd
       ├── Renewables.Rmd
       ├── Renewables and Coal.Rmd
       ├── Solar.Rmd
       ├── Wind.Rmd
       ├── Storage.Rmd
       ├── Natural Gas.Rmd
       ├── Energy Consumption.Rmd
       ├── Electrical System Losses.Rmd
       ├── Residential and Commercial Consumption.Rmd
       └── Reliability.Rmd
   ```
3. Open `EIA_Data_Viewer.Rmd` in RStudio and click **Knit**, or render from the console:
   ```r
   rmarkdown::render("EIA_Data_Viewer.Rmd")
   ```
4. The output is a self-contained HTML file with tabbed navigation. Open it in any browser.

## Data Sources

| Source | Used By |
|--------|---------|
| EIA v2 API — Electricity Operational Data | Net Generation, Renewables, Renewables and Coal, Natural Gas |
| EIA v2 API — SEDS (State Energy Data System) | Renewables, Energy Consumption, Residential and Commercial Consumption, Electrical System Losses |
| EIA v2 API — Natural Gas Prices | Natural Gas |
| EIA Published Spreadsheets (direct download) | Net Generation (verification), Renewables and Coal (emissions) |
| EIA Website (web scraping) | Reliability (SAIDI/SAIFI tables) |
| Internal DuckDB Database | Solar, Wind, Storage |

## Notes

- The report automatically stamps each run with the current date so you can track when data was last refreshed.
- All charts source-cite EIA or the MN PUC in their captions.
- Each visualization includes a **Download Plot** button (`.png`) and most datasets include a **Download Data** button (`.xlsx`) embedded in the rendered HTML.
- The Renewables tab's energy consumption chart still references the SEDS endpoint, which the Overview tab notes may need updating once SEDS is fully available in the v2 API.
- The MROW (Midwest Reliability Organization West) generation chart on the Net Generation tab uses hardcoded 2021 values from the EPA Power Profiler rather than a live API call.