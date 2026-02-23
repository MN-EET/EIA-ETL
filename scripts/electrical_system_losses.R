# scripts/electrical_system_losses.R
source(here::here("scripts", "helpers.R"))

cat("=== Electrical System Losses ===\n")

raw <- GET(paste0("https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=", eia_key,
  "&facets[seriesId][]=LOTCB&facets[stateId][]=MN&start=2004&sort[0][column]=period&sort[0][direction]=asc&offset=0&length=5000"))

energy_losses <- fromJSON(rawToChar(raw$content))$response$data |>
  tibble() |>
  mutate(year = as.numeric(period), loss_billion_btu = as.numeric(value)) |>
  select(year, loss_billion_btu)

save_data(energy_losses, "electrical_system_losses.csv")

loss_goal <- energy_losses |> filter(year == 2005) |> mutate(goal = loss_billion_btu * .85) |> pull(goal)
graph_max <- max(energy_losses$loss_billion_btu) * 1.1
graph_min <- .7 * loss_goal
annotate_x <- min(energy_losses$year) + 1
annotate_y <- loss_goal * 1.015

p <- energy_losses |>
  ggplot() + aes(x = year, y = loss_billion_btu) +
  geom_line(color = "#003865", linewidth = 1) +
  theme_eia() +
  geom_hline(yintercept = loss_goal) +
  annotate("text", x = annotate_x, y = annotate_y, label = "2030 Goal") +
  ylim(graph_min, graph_max) +
  xlab("Year") + ylab("Billion BTU") +
  ggtitle("Measure 4.5 - By 2030, reduce energy use by 10% and total \nwaste heat and waste electricity by 15%, compared to 2005 levels")
save_plot(p, "electrical_system_losses.png")

cat("=== Electrical System Losses complete ===\n\n")
