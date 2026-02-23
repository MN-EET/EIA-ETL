# scripts/energy_consumption.R
source(here::here("scripts", "helpers.R"))

cat("=== Energy Consumption ===\n")

api_cleanup <- function(raw_data, fuel_type) {
  x <- fromJSON(rawToChar(raw_data$content))
  tibble(x$response$data) |>
    mutate(fuel = fuel_type, period = as.numeric(period), value = as.numeric(value)) |>
    select(period, fuel, value)
}

# Fetch all fuel types
petro     <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=PMTCB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Petroleum")
imports   <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=ELNIB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Imports")
net_inter <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=ELISB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Imports")
renewables <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=RETCB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Renewables")
coal      <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=CLTCB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Coal")
gas       <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=NNTCB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Natural Gas")
nuclear   <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=NUETB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Nuclear")
total     <- api_cleanup(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[seriesId][]=TETCB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")), "Total")

imports <- imports |> bind_rows(net_inter) |> group_by(period) |> summarise(value = sum(value)) |> mutate(fuel = "Imports")

consumption_totals <- bind_rows(total, petro, imports, renewables, coal, gas, nuclear)

consumption_percent <- bind_rows(total, petro, imports, renewables, coal, gas, nuclear) |>
  pivot_wider(names_from = fuel, values_from = value) |>
  mutate(across(c(Petroleum, Imports, Renewables, Coal, `Natural Gas`, Nuclear), .fns = ~ . / Total)) |>
  select(-Total) |>
  pivot_longer(!period, names_to = "Fuel", values_to = "Percent")

save_data(consumption_totals, "energy_consumption_mn.csv")

top_year <- max(consumption_totals$period)
bottom_year <- 2003

fuel_colors <- c("Renewables" = "#78BE21", "Nuclear" = "#008EAA", "Coal" = "#000000",
                 "Natural Gas" = "#8D3F2B", "Imports" = "#F5E1A4", "Petroleum" = "#97999B")

# 1. Consumption Trend
p <- consumption_totals |>
  filter(fuel != "Total", period >= bottom_year) |>
  mutate(value = value / 1000) |>
  ggplot() + aes(x = period, y = value) +
  geom_line(aes(colour = factor(fuel)), linewidth = 1) +
  scale_color_manual(values = fuel_colors, name = "") +
  theme_eia() + xlab("Year") + ylab("Trillion BTU") +
  ggtitle("Minnesota Energy Consumption") +
  scale_x_continuous(breaks = seq(bottom_year, top_year, by = 5), limits = c(bottom_year, top_year)) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "energy_consumption_trend.png")

# 2. Change in Consumption
top_year <- consumption_totals |> filter(fuel == "Total") |> filter(period == max(period)) |> pull(period)
bottom_year <- 2003

data_use <- consumption_percent |>
  filter(period == top_year | period == bottom_year) |>
  mutate(percent_label = paste0(round(Percent * 100), "%"),
         nudge_factor = ifelse(period == top_year, 1, -1))

p <- data_use |>
  ggplot() + aes(x = period, y = Percent, label = percent_label) +
  geom_point(aes(colour = factor(Fuel)), size = 3) +
  geom_line(aes(colour = factor(Fuel)), linewidth = 1) +
  geom_text_repel(nudge_x = data_use$nudge_factor, size = 3.5) +
  scale_color_manual(values = fuel_colors, name = "") +
  theme_eia() + theme(axis.title.y = element_blank()) +
  xlab("Year") + ggtitle("Change in Energy Consumption") +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = c(bottom_year, top_year), limits = c(bottom_year - 3, top_year + 3)) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "change_in_energy_consumption.png")

# 3. Renewable consumption MN vs US
api_cleaner_re <- function(raw) {
  x <- fromJSON(rawToChar(raw$content))
  x$response$data |>
    select(period, seriesId, stateDescription, value) |>
    pivot_wider(names_from = "seriesId", values_from = "value") |>
    mutate(percent_renewable = as.numeric(RETCB) / as.numeric(TETCB),
           period = as.numeric(period),
           percent_label = case_when(period == max(period) ~ paste0(round(percent_renewable * 100), "%"), TRUE ~ "")) |>
    select(period, stateDescription, percent_renewable, percent_label)
}

mn_con <- api_cleaner_re(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[stateId][]=MN&facets[seriesId][]=RETCB&facets[seriesId][]=TETCB&start=2003&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")))
us_con <- api_cleaner_re(GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key, "&facets[stateId][]=US&facets[seriesId][]=RETCB&facets[seriesId][]=TETCB&start=2003&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000")))

total_consumption <- bind_rows(mn_con, us_con)
area_colors <- c("Minnesota" = "#78BE21", "United States" = "#000000")
top_year <- max(mn_con$period)
bottom_year <- min(mn_con$period)

p <- total_consumption |>
  ggplot() + aes(x = period, y = percent_renewable, color = stateDescription) +
  geom_line(linewidth = 1) +
  geom_text(aes(label = percent_label), nudge_x = 1, show.legend = FALSE) +
  scale_color_manual(values = area_colors, name = "") +
  theme_eia() +
  scale_y_continuous(labels = scales::percent, limits = c(0, .2)) +
  scale_x_continuous(name = "Year", limits = c(bottom_year, top_year + 3), breaks = seq(bottom_year, top_year, by = 5)) +
  ggtitle("Minnesota and US Renewable Consumption Trend") +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today)) +
  ylab("Percent of Total Energy Consumption")
save_plot(p, "renewable_consumption_mn_vs_us.png")

cat("=== Energy Consumption complete ===\n\n")
