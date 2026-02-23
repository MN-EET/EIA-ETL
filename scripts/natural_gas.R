# scripts/natural_gas.R
source(here::here("scripts", "helpers.R"))
library(lubridate)
library(zoo)

cat("=== Natural Gas ===\n")

# Henry Hub spot prices
henry_hub <- GET(paste0("https://api.eia.gov/v2/natural-gas/pri/fut/data/?api_key=", eia_key,
  "&frequency=monthly&data[0]=value&facets[series][]=RNGWHHD&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000"))
henry_hub <- tibble(fromJSON(rawToChar(henry_hub$content))$response$data)
save_data(henry_hub |> select(period, `product-name`, value, units), "henry_hub_prices.csv")

# 1. Henry Hub price chart
price_label <- paste0("$", henry_hub |> filter(period == max(period)) |> pull(value))
vline_russia <- ym("2022-02")
vline_yuri <- ym("2021-02")

p <- henry_hub |>
  mutate(period = ym(period), value = as.numeric(value)) |>
  arrange(desc(period)) |>
  mutate(price_label = ifelse(period == max(period), price_label, "")) |>
  slice(1:60) |>
  ggplot() + aes(x = period, y = value) +
  geom_line(color = "#000000", linewidth = 1) +
  geom_text_repel(aes(label = price_label), nudge_x = 1) +
  theme_eia() + theme(axis.title.x = element_blank()) +
  ylab("Dollar per MMBTU") + ggtitle("Monthly Henry Hub Natural Gas Spot Price") +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today)) +
  geom_vline(xintercept = vline_russia) +
  annotate("text", x = vline_russia - 20, y = 7, label = "Russia Invades Ukraine", angle = 90, size = 3.5) +
  geom_vline(xintercept = vline_yuri) +
  annotate("text", x = vline_yuri - 20, y = 7, label = "Winter Storm Yuri", angle = 90, size = 3.5) +
  ylim(0, 10)
save_plot(p, "henry_hub_spot_price.png")

# 2. Natural Gas volatility in electricity generation
start_date <- "2021-01-01"
monthly_gen <- GET(paste0("https://api.eia.gov/v2/electricity/electric-power-operational-data/data?api_key=", eia_key,
  "&data[]=generation&frequency=monthly&facets[location][]=MN&facets[sectorid][]=99&start=", start_date))
monthly_gen <- fromJSON(rawToChar(monthly_gen$content))

monthly_gen <- monthly_gen$response$data |>
  tibble() |> clean_names() |>
  mutate(generation = as.numeric(generation)) |>
  filter(fuel_type_description %in% c("natural gas", "all fuels")) |>
  select(period, fuel_type_description, generation) |>
  pivot_wider(names_from = fuel_type_description, values_from = generation) |>
  arrange(period) |>
  mutate(period = ym(period),
         `Natural Gas` = rollmean(`natural gas`, 12, na.pad = TRUE, align = "right"),
         all = rollmean(`all fuels`, 12, na.pad = TRUE, align = "right"),
         `Natural Gas` = `Natural Gas` / all) |>
  select(period, `Natural Gas`) |>
  pivot_longer(!period, names_to = "fuel", values_to = "generation") |>
  filter(complete.cases(generation)) |>
  arrange(desc(period))

vline_russia <- monthly_gen |> filter(period == as.Date("2022-02-01")) |> pull(period)

p <- monthly_gen |>
  mutate(label = ifelse(period == max(period), paste0(round(generation * 100), "%"), "")) |>
  ggplot() + aes(x = period, y = generation) +
  geom_line(aes(color = fuel), linewidth = 1.2) +
  scale_color_manual(values = "#8D3F2B", name = "", guide = "none") +
  scale_x_date(breaks = seq(from = min(monthly_gen$period), to = max(monthly_gen$period), by = "6 months")) +
  theme_eia() + theme(axis.text.x = element_text(angle = 45, vjust = .5), axis.title.x = element_blank()) +
  scale_y_continuous(labels = scales::percent, name = "12 Month Moving Average", limits = c(0, .5)) +
  ggtitle("Natural Gas Volatility in Electricity Generation") +
  geom_text_repel(aes(label = label), nudge_x = 1.5, size = 3.5) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today)) +
  geom_vline(xintercept = vline_russia) +
  annotate("text", x = vline_russia - 20, y = .35, label = "Russia Invades Ukraine", angle = 90, size = 3.5)
save_plot(p, "natural_gas_volatility.png")

cat("=== Natural Gas complete ===\n\n")
