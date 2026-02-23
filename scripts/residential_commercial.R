# scripts/residential_commercial.R
source(here::here("scripts", "helpers.R"))

cat("=== Residential and Commercial Consumption ===\n")

seds_fetch <- function(series_id) {
  GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key,
    "&facets[seriesId][]=", series_id, "&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=asc&offset=0&length=5000"))
}

api_cleanup <- function(raw_data, sector, fuel_type) {
  x <- fromJSON(rawToChar(raw_data$content))
  tibble(x$response$data) |>
    mutate(year = as.numeric(period), value = as.numeric(value), Sector = sector, fuel_type = fuel_type) |>
    select(year, value, Sector, fuel_type)
}

total_res <- api_cleanup(seds_fetch("TERCB"), "Residential", "Total")
elec_res  <- api_cleanup(seds_fetch("ESRCB"), "Residential", "Electricity")
gas_res   <- api_cleanup(seds_fetch("NGRCB"), "Residential", "Natural Gas")
total_com <- api_cleanup(seds_fetch("TNCSB"), "Commercial", "Total")
elec_com  <- api_cleanup(seds_fetch("ESCCB"), "Commercial", "Electricity")
gas_com   <- api_cleanup(seds_fetch("NGCCB"), "Commercial", "Natural Gas")
total_ind <- api_cleanup(seds_fetch("TNISB"), "Industrial", "Total")
elec_ind  <- api_cleanup(seds_fetch("ESICB"), "Industrial", "Electricity")
gas_ind   <- api_cleanup(seds_fetch("NGICB"), "Industrial", "Natural Gas")

# 1. Total energy by sector
total_energy <- bind_rows(total_res, total_com, total_ind) |> filter(year >= 2003)
graph_max <- max(total_energy$value) * 1.1
save_data(total_energy, "sector_energy_consumption.csv")

p <- total_energy |>
  ggplot() + aes(x = year, y = value, color = Sector) + geom_line(linewidth = 1) +
  theme_eia() + scale_color_manual(values = c("#003865", "#78BE21", "#E57200")) +
  ylim(0, graph_max) +
  ggtitle("Total Energy Consumption - Residential and Commercial Customers") +
  ylab("Billion Btu") + xlab("Year")
save_plot(p, "sector_total_energy.png")

# 2. Electricity by sector
total_electricity <- bind_rows(elec_res, elec_com) |> filter(year >= 2005)
p <- total_electricity |>
  ggplot() + aes(x = year, y = value, color = Sector) + geom_line(linewidth = 1) +
  theme_eia() + scale_color_manual(values = c("#003865", "#78BE21")) +
  ylim(0, graph_max) +
  ggtitle("Total Electricity Consumption - Residential and Commercial Customers") +
  ylab("Billion Btu") + xlab("Year")
save_plot(p, "sector_electricity.png")

# 3. Gas by sector
total_gas <- bind_rows(gas_res, gas_com) |> filter(year >= 2005)
p <- total_gas |>
  ggplot() + aes(x = year, y = value, color = Sector) + geom_line(linewidth = 1) +
  theme_eia() + scale_color_manual(values = c("#003865", "#78BE21")) +
  ylim(0, graph_max) +
  ggtitle("Total Gas Consumption - Residential and Commercial Customers") +
  ylab("Billion Btu") + xlab("Year")
save_plot(p, "sector_gas.png")

# 4. Combined electricity + gas
total_elec_gas <- bind_rows(total_electricity, total_gas) |>
  group_by(year, Sector) |> summarise(value = sum(value), .groups = "drop")
graph_max2 <- max(total_elec_gas$value) * 1.1

p <- total_elec_gas |>
  ggplot() + aes(x = year, y = value, color = Sector) + geom_line(linewidth = 1) +
  theme_eia() + scale_color_manual(values = c("#003865", "#78BE21")) +
  ylim(0, graph_max2) +
  ggtitle("Total Electricity and Gas Consumption - Residential and Commercial Customers") +
  ylab("Billion Btu") + xlab("Year")
save_plot(p, "sector_elec_and_gas.png")

cat("=== Residential and Commercial complete ===\n\n")
