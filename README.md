# EIA Electricity Generation Plots

Electricity generation charts for Minnesota, sourced from the [U.S. Energy Information Administration API](https://www.eia.gov/opendata/).

## How to Run

1. Store your EIA API key in the system keyring (one-time setup):
   ```r
   keyring::key_set("eia_api")
   ```

2. Run the script:
   ```r
   source("generate_plots.R")
   ```

3. Plots and CSVs are saved to the `output/` folder. Open `index.html` to browse them.

## Publishing to GitHub Pages

1. Push this repo to GitHub (including the `output/` folder after running the script)
2. Go to repo **Settings → Pages**
3. Source: **Deploy from a branch**
4. Branch: `main` / `root`
5. Save

Plots will be available at `https://<username>.github.io/<repo-name>/output/`

Use those URLs in SharePoint, PowerPoint, or anywhere that accepts image links.

## Plots Generated

| File | Description |
|------|-------------|
| `electricity_generation_mn.png` | MN generation by source - most recent year |
| `change_in_generation_mn.png` | MN generation change over 15 years |
| `generation_trend_mn.png` | MN generation trend (2000-current) |
| `total_and_renewable_generation.png` | MN total vs renewable generation |
| `electricity_generation_us.png` | U.S. generation by source - most recent year |
| `change_in_generation_us.png` | U.S. generation change over 15 years |
| `electricity_generation_midwest.png` | Midwest generation by source |
| `electricity_generation_mrow.png` | MROW region (EPA data, hardcoded) |
