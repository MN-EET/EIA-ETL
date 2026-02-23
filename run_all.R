# run_all.R
# Master script: sources each individual script and copies the index page.
# Run from the project root: source("run_all.R")

library(here)

cat("========================================\n")
cat("  EIA Data Pipeline - Starting\n")
cat("  ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("========================================\n\n")

# --- EIA API scripts (no database needed) ---
source(here("scripts", "net_generation.R"))
source(here("scripts", "energy_consumption.R"))
source(here("scripts", "natural_gas.R"))
source(here("scripts", "renewables.R"))
source(here("scripts", "renewables_and_coal.R"))
source(here("scripts", "reliability.R"))
source(here("scripts", "residential_commercial.R"))
source(here("scripts", "electrical_system_losses.R"))

# --- Database scripts (require DuckDB access) ---
# Comment these out if running without the generator database
source(here("scripts", "solar.R"))
source(here("scripts", "wind.R"))
source(here("scripts", "storage.R"))

# --- Copy index page to output ---
file.copy(here("index.html"), here("output", "index.html"), overwrite = TRUE)

cat("========================================\n")
cat("  Pipeline complete!\n")
cat("  Plots saved to: ", here("output", "plots"), "\n")
cat("  Data saved to:  ", here("output", "data"), "\n")
cat("  Website at:     ", here("output", "index.html"), "\n")
cat("========================================\n")
