# scripts/net_generation.R
source(here::here("scripts", "helpers.R"))

cat("=== Net Generation ===\n")

# Shared data cleaner
gen_data_cleaner <- function(x) {
  fuel_labels <- c(
    "all renewables" = "Renewables", "natural gas" = "Natural Gas",
    "all coal products" = "Coal", "wind" = "Wind", "solar" = "Solar",
    "nuclear" = "Nuclear", "all fuels" = "All Fuels", "biomass" = "Biomass",
    "conventional hydroelectric" = "Conventional Hydroelectric",
    "other" = "Other", "petroleum liquids" = "Petroleum Liquids"
  )
  fuel_ids <- c("BIO", "HYC", "SUN", "WND", "COW", "NG", "PEL", "NUC", "OTH", "ALL", "AOR")

  generation_perc <- x$response$data |>
    tibble() |> arrange(desc(as.numeric(period))) |> clean_names() |>
    filter(fueltypeid %in% fuel_ids) |>
    mutate(fuel_type_description = str_replace_all(fuel_type_description, fuel_labels),
           generation = as.numeric(generation)) |>
    select(period, fuel_type_description, generation) |>
    pivot_wider(names_from = fuel_type_description, values_from = generation) |>
    mutate(Renewables = Renewables + `Conventional Hydroelectric`) |>
    mutate(across(c(2:12), .fns = ~ . / `All Fuels`)) |>
    select(period, 2:12) |>
    pivot_longer(!period, names_to = "fuel_type_description", values_to = "generation")

  x$response$data |>
    tibble() |> clean_names() |>
    filter(fueltypeid %in% fuel_ids) |>
    mutate(fuel_type_description = str_replace_all(fuel_type_description, fuel_labels),
           generation = as.numeric(generation)) |>
    select(period, fuel_type_description, generation) |>
    pivot_wider(names_from = fuel_type_description, values_from = generation) |>
    mutate(Renewables = Renewables + `Conventional Hydroelectric`) |>
    pivot_longer(!period, names_to = "fuel_type_description", values_to = "generation") |>
    left_join(generation_perc, by = c("period", "fuel_type_description")) |>
    rename(total_generation_thousand_mwh = 3, percent_generation = 4) |>
    arrange(period, fuel_type_description)
}

# --- MN Data ---
raw_generation <- fetch_eia_generation("MN")
generation_total <- gen_data_cleaner(raw_generation)
save_data(generation_total, "electricity_generation_mn.csv")

# 1. MN Generation bar chart
title_year <- as.character(max(generation_total$period))
p <- generation_total |>
  filter(fuel_type_description %in% c("Renewables", "Coal", "Natural Gas", "Nuclear")) |>
  mutate(percent_label = paste0(round(percent_generation * 100), "%")) |>
  filter(period == max(period)) |>
  ggplot() + aes(x = percent_generation, y = fct_reorder(as_factor(fuel_type_description), percent_generation), label = percent_label) +
  geom_bar(stat = "identity", fill = "#003865") + geom_text(nudge_x = .02) +
  theme_eia() + theme(axis.title.y = element_blank()) +
  xlab("Percent") + ggtitle(paste0("Electricity Generation in Minnesota ", title_year)) +
  scale_x_continuous(labels = scales::percent, limits = c(0, .4)) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "electricity_generation_mn.png")

# 2. Change in MN Generation
fuel_colors <- c("Renewables" = "#78BE21", "Nuclear" = "#008EAA", "Coal" = "#000000", "Natural Gas" = "#8D3F2B")
top_year <- max(as.numeric(generation_total$period))
bottom_year <- top_year - 15

data_use <- generation_total |>
  mutate(period = as.numeric(period)) |>
  filter(period == top_year | period == bottom_year) |>
  filter(fuel_type_description %in% c("Renewables", "Coal", "Nuclear", "Natural Gas")) |>
  mutate(percent_label = paste0(round(percent_generation * 100), "%"),
         nudge_factor = ifelse(period == top_year, 1, -1))

p <- data_use |>
  ggplot() + aes(x = period, y = percent_generation, label = percent_label) +
  geom_point(aes(colour = factor(fuel_type_description)), size = 3) +
  geom_line(aes(colour = factor(fuel_type_description)), linewidth = 1) +
  geom_text_repel(nudge_x = data_use$nudge_factor, size = 3.5) +
  scale_color_manual(values = fuel_colors, name = "") +
  theme_eia() + theme(axis.title.y = element_blank(), legend.position = c(.7, .8)) +
  xlab("Year") + ggtitle("Change in Electricity Generation - Minnesota") +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = c(bottom_year, top_year), limits = c(bottom_year - 3, top_year + 3)) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "change_in_generation_mn.png")

# 3. MN Generation Trend
bottom_year <- min(as.numeric(generation_total$period))
top_year <- max(as.numeric(generation_total$period))

p <- generation_total |>
  mutate(period = as.numeric(period)) |>
  filter(fuel_type_description %in% c("Coal", "Nuclear", "Natural Gas", "Renewables")) |>
  mutate(percent_label = ifelse(period == top_year, paste0(round(percent_generation * 100), "%"), "")) |>
  ggplot() + aes(x = period, y = percent_generation) +
  geom_line(aes(colour = factor(fuel_type_description)), linewidth = 1) +
  scale_color_manual(values = fuel_colors, name = "") +
  theme_eia() + theme(axis.title.y = element_blank()) +
  xlab("Year") + ggtitle("Electricity Generation Trend - Minnesota") +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(bottom_year, top_year, by = 5), limits = c(bottom_year, top_year + 3)) +
  geom_text_repel(aes(label = percent_label), nudge_x = 1, size = 3.5) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "generation_trend_mn.png")

# 4. Total and Renewable Generation
fuel_colors_total <- c("Renewables" = "#78BE21", "All Fuels" = "#003865")
p <- generation_total |>
  mutate(period = as.numeric(period),
         gen_label = case_when(period == max(period) ~ as.character(round(total_generation_thousand_mwh, 0)), TRUE ~ "")) |>
  filter(fuel_type_description %in% c("All Fuels", "Renewables"), period >= bottom_year) |>
  ggplot() + aes(x = period, y = total_generation_thousand_mwh) +
  geom_line(aes(color = factor(fuel_type_description)), linewidth = 1) +
  scale_color_manual(values = fuel_colors_total, name = "") +
  scale_x_continuous(name = "Year", breaks = seq(bottom_year, top_year, by = 5), limits = c(bottom_year, top_year + 2)) +
  geom_text_repel(aes(label = gen_label), nudge_x = 1) +
  theme_eia() +
  ggtitle("Minnesota Electricity Generation - Total and Renewables") +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today)) +
  ylab("Thousand Megawatthours")
save_plot(p, "total_and_renewable_generation.png")

# --- US Data ---
raw_us <- fetch_eia_generation("US")
generation_total_us <- gen_data_cleaner(raw_us)
save_data(generation_total_us, "electricity_generation_us.csv")

# 5. US Generation bar chart
title_year <- as.character(max(generation_total_us$period))
p <- generation_total_us |>
  filter(fuel_type_description %in% c("Renewables", "Coal", "Natural Gas", "Nuclear")) |>
  mutate(percent_label = paste0(round(percent_generation * 100), "%")) |>
  filter(period == max(period)) |>
  ggplot() + aes(x = percent_generation, y = fct_reorder(as_factor(fuel_type_description), percent_generation), label = percent_label) +
  geom_bar(stat = "identity", fill = "#003865") + geom_text(nudge_x = .02) +
  theme_eia() + theme(axis.title.y = element_blank()) +
  xlab("Percent") + ggtitle(paste0("Electricity Generation in U.S. ", title_year)) +
  scale_x_continuous(labels = scales::percent) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "electricity_generation_us.png")

# 6. Change in US Generation
top_year <- max(as.numeric(generation_total_us$period))
bottom_year <- top_year - 15
data_use <- generation_total_us |>
  mutate(period = as.numeric(period)) |>
  filter(period == top_year | period == bottom_year) |>
  filter(fuel_type_description %in% c("Renewables", "Coal", "Nuclear", "Natural Gas")) |>
  mutate(percent_label = paste0(round(percent_generation * 100), "%"),
         nudge_factor = ifelse(period == top_year, 1, -1))

p <- data_use |>
  ggplot() + aes(x = period, y = percent_generation, label = percent_label) +
  geom_point(aes(colour = factor(fuel_type_description)), size = 3) +
  geom_line(aes(colour = factor(fuel_type_description)), linewidth = 1) +
  geom_text_repel(nudge_x = data_use$nudge_factor, size = 3.5) +
  scale_color_manual(values = fuel_colors, name = "") +
  theme_eia() + theme(axis.title.y = element_blank()) +
  xlab("Year") + ggtitle("Change in Electricity Generation - U.S.") +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = c(bottom_year, top_year), limits = c(bottom_year - 3, top_year + 3)) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "change_in_generation_us.png")

# 7. Midwest Generation
raw_wnc <- fetch_eia_generation("WNC")
raw_enc <- fetch_eia_generation("ENC")
wnc <- gen_data_cleaner(raw_wnc)
enc <- gen_data_cleaner(raw_enc)

midwest <- suppressMessages(
  wnc |> bind_rows(enc) |>
    filter(period == max(period), fuel_type_description %in% c("All Fuels", "Coal", "Renewables", "Natural Gas", "Nuclear")) |>
    select(period, fuel_type_description, total_generation_thousand_mwh) |>
    group_by(period, fuel_type_description) |>
    summarise(total = sum(total_generation_thousand_mwh)) |>
    pivot_wider(names_from = fuel_type_description, values_from = total) |>
    mutate(across(c(Coal, `Natural Gas`, Nuclear, Renewables), ~ . / `All Fuels`)) |>
    select(-`All Fuels`) |>
    pivot_longer(!period, names_to = "fuel_type_description", values_to = "percent_generation") |>
    mutate(percent_label = paste0(round(percent_generation * 100), "%"))
)

p <- midwest |>
  ggplot() + aes(x = percent_generation, y = fct_reorder(as_factor(fuel_type_description), percent_generation), label = percent_label) +
  geom_bar(stat = "identity", fill = "#003865") + geom_text(nudge_x = .02) +
  theme_eia() + theme(axis.title.y = element_blank()) +
  xlab("Percent") + ggtitle(paste0("Electricity Generation in Midwest ", max(midwest$period))) +
  scale_x_continuous(labels = scales::percent) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "electricity_generation_midwest.png")

# 8. MROW (hardcoded EPA data)
p <- tribble(
  ~period, ~fuel_type_description, ~percent_generation, ~percent_label,
  "2021", "Coal", .396, "40%",
  "2021", "Natural Gas", .106, "11%",
  "2021", "Nuclear", .086, "9%",
  "2021", "Renewables", .407, "41%"
) |>
  ggplot() + aes(x = percent_generation, y = fct_reorder(as_factor(fuel_type_description), percent_generation), label = percent_label) +
  geom_bar(stat = "identity", fill = "#003865") + geom_text(nudge_x = .02) +
  theme_eia() + theme(axis.title.y = element_blank()) +
  xlab("Percent") + ggtitle("Electricity Generation - MROW 2021") +
  scale_x_continuous(labels = scales::percent) +
  labs(caption = "Source: Environmental Protection Agency\nPercentages Exceed 100% Due to Rounding")
save_plot(p, "electricity_generation_mrow.png")

cat("=== Net Generation complete ===\n\n")
