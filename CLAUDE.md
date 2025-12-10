# Data Desk Research Notebooks

Data Desk publishes investigative research as interactive notebooks using Observable Notebook Kit 2.0. Notebooks are standalone HTML pages with embedded JavaScript that compile to static sites.

## File Structure

```
repo/
├── docs/
│   ├── index.html           # Notebook source (EDIT THIS)
│   ├── assets/              # Images
│   └── .observable/dist/    # Built output (gitignored)
├── data/                    # DuckDB, CSV, JSON files
├── template.html            # HTML wrapper (auto-updates from .github repo)
├── Makefile
└── CLAUDE.md                # This file (auto-updates)
```

**Commit:** `docs/index.html`, `data/*`, `docs/assets/*`, `Makefile`
**Don't commit:** `docs/.observable/dist/`, `node_modules/`, `template.html`, `CLAUDE.md`

## Observable Notebook Basics

Notebooks use `<notebook>` element, not Jupyter format. Reactive execution: cells auto-run when dependencies change.

### Cell Types

```html
<!doctype html>
<notebook theme="midnight">
  <title>Research Title</title>

  <!-- Markdown -->
  <script id="header" type="text/markdown">
    # Heading
  </script>

  <!-- JavaScript -->
  <script id="analysis" type="module">
    const data = await FileAttachment("../data/flows.csv").csv({typed: true});
    display(Inputs.table(data));
  </script>

  <!-- SQL (queries DuckDB) -->
  <script id="flows" output="flows" type="application/sql" database="../data/data.duckdb" hidden>
    SELECT * FROM flows ORDER BY date DESC
  </script>

  <!-- Raw HTML -->
  <script id="chart" type="text/html">
    <div id="map" style="height: 500px;"></div>
  </script>
</notebook>
```

**Key points:**
- Each `<script>` has unique `id`
- Cells are `type="module"` by default (ES6 syntax)
- Use `display()` to render output (don't rely on return values)
- Variables defined in one cell available to all others

## Loading Data

### FileAttachment API

Paths relative to notebook (`docs/index.html`):
- Data files in root `data/` → use `../data/`
- Assets in `docs/assets/` → use `assets/`
- Always `await` FileAttachment calls

```javascript
// CSV with type inference
const flows = await FileAttachment("../data/flows.csv").csv({typed: true});

// JSON
const projects = await FileAttachment("../data/projects.json").json();

// Parquet
const tracks = await FileAttachment("../data/tracks.parquet").parquet();

// Images
const img = await FileAttachment("assets/photo.jpg").url();
```

### DuckDB / SQL Cells

SQL cells query DuckDB at build time, results embedded in HTML.

```html
<script id="query" output="flows" type="application/sql" database="../data/data.duckdb" hidden>
  SELECT * FROM flows WHERE year >= 2020
</script>
```

**Attributes:**
- `type="application/sql"` - marks as SQL query
- `database="../data/data.duckdb"` - path to database (relative to notebook)
- `output="flows"` - variable name for results
- `hidden` - don't display output (optional)

Results available as JS variable:
```javascript
display(html`<p>Found ${flows.length} flows</p>`);
```

### DuckDB Client (for complex queries)

```javascript
const db = DuckDBClient.of();
const summary = await db.query(`
  SELECT year, count(*) as n, sum(volume_kt) as total
  FROM flows GROUP BY year ORDER BY year
`);
display(Inputs.table(summary));
```

## Visualization

### Observable Plot

```javascript
display(Plot.plot({
  title: "Annual volumes by destination",
  x: {label: "Year"},
  y: {label: "Volume (Mt)", grid: true},
  color: {legend: true},
  marks: [
    Plot.barY(data, {x: "year", y: "volume", fill: "region", tip: true}),
    Plot.ruleY([0])
  ]
}));
```

**Common marks:** `Plot.line()`, `Plot.barY()`, `Plot.areaY()`, `Plot.dot()`
**Built-in:** automatic scales, tooltips with `tip: true`, responsive layout

### Interactive Inputs

```javascript
// Toggle
const show_all = view(Inputs.toggle({label: "Show all columns"}));

// Search
const searched = view(Inputs.search(data));

// Table
display(Inputs.table(searched, {
  rows: 25,
  columns: show_all ? undefined : ["name", "date", "value"]
}));

// Slider, select, etc.
const threshold = view(Inputs.range([0, 100], {step: 1, value: 50}));
const country = view(Inputs.select(["UK", "Norway", "Sweden"]));
```

`view()` makes input reactive - other cells auto-update when value changes.

### External Libraries

Load via dynamic imports or CDN:

```html
<!-- CSS -->
<script type="text/html">
  <link href="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css" rel="stylesheet" />
</script>

<!-- JS library -->
<script type="module">
  const script = document.createElement('script');
  script.src = 'https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js';
  script.onload = () => initMap();
  document.head.appendChild(script);
</script>
```

## Build & Deploy

### Makefile Targets

Every notebook should define two data targets:

| Target | Purpose | Where |
|--------|---------|-------|
| `make etl` | Expensive computation (large downloads, model training, heavy processing) | Local only |
| `make data` | Lightweight refresh (fetch artifacts, run analysis, export for notebook) | GitHub Actions |

**Simple notebook (no heavy step):**
```makefile
.PHONY: build preview etl data clean

build:
	yarn build

preview:
	yarn preview

etl: data  # no heavy step, just alias

data:
	python scripts/fetch_and_process.py

clean:
	rm -rf docs/.observable/dist
```

**Complex notebook (with heavy ETL):**
```makefile
.PHONY: build preview etl data clean

build:
	yarn build

preview:
	yarn preview

# Expensive local computation - run manually, upload artifacts to GitHub Releases
etl: data/infrastructure.duckdb
	@echo "Done. Upload to GitHub Releases:"
	@echo "  gzip -k data/infrastructure.duckdb"
	@echo "  gh release create v1 data/infrastructure.duckdb.gz"

data/infrastructure.duckdb: data/source.gpkg scripts/build_infra.py
	python scripts/build_infra.py

# CI-friendly refresh - downloads artifacts, runs lightweight analysis
data:
	@if [ ! -f data/infrastructure.duckdb ]; then \
		echo "Downloading from GitHub Releases..."; \
		gh release download latest -p infrastructure.duckdb.gz -D data && \
		gunzip data/infrastructure.duckdb.gz; \
	fi
	python scripts/analyze.py
	duckdb data/data.duckdb < queries/export.sql

clean:
	rm -rf docs/.observable/dist data/data.duckdb
```

**Usage:**
- `make preview` - local dev server with hot reload (http://localhost:3000)
- `make build` - compile to `docs/.observable/dist/`
- `make etl` - run expensive local computation (manual, infrequent)
- `make data` - lightweight data refresh (runs in GitHub Actions)
- `make clean` - remove build artifacts

### Build Process

Compiles `docs/index.html` into standalone page:
1. Parse `<notebook>` element
2. Compile JS cells to modules
3. Bundle dependencies
4. Apply `template.html`
5. Output to `docs/.observable/dist/`

**Important:** SQL cells query at build time. Database needed for build, not deployment (results embedded in HTML).

### GitHub Actions Deployment

Each notebook repo has a minimal `deploy.yml` that calls a shared reusable workflow:

```yaml
name: Deploy notebook

on:
  schedule:
    - cron: '0 6 1 * *'  # Monthly - adjust per repo
  workflow_dispatch:
  push:
    branches: [main]

jobs:
  deploy:
    uses: data-desk-eco/.github/.github/workflows/notebook-deploy.yml@main
    permissions:
      contents: write
      pages: write
      id-token: write
    secrets: inherit
```

The reusable workflow handles:
1. Checkout and setup (Node, Yarn, DuckDB)
2. Download shared `template.html` and `CLAUDE.md`
3. Run `make data`
4. Commit any changes
5. Run `make build`
6. Deploy to GitHub Pages

**Pages setup:** Settings → Pages → Source: GitHub Actions

**Skip data step:** For notebooks without a data target:
```yaml
jobs:
  deploy:
    uses: data-desk-eco/.github/.github/workflows/notebook-deploy.yml@main
    with:
      skip_data: true
    # ...
```

## Common Patterns

### Data Aggregation

```javascript
// Group by and sum
const annual = d3.rollup(flows, v => d3.sum(v, d => d.volume), d => d.year);

// Map to array
const data = Array.from(annual, ([year, volume]) => ({year, volume}))
  .sort((a, b) => a.year - b.year);
```

### Formatting

```javascript
const formatDate = d3.utcFormat("%B %Y");
const formatNumber = d3.format(",.1f");
const formatCurrency = d3.format("$,.0f");
```

### Inline Calculations in Markdown

```javascript
// Calculate stats
const total = d3.sum(flows, d => d.volume);
const maxYear = d3.max(flows, d => d.year);
```

Reference in markdown:
```html
<script type="text/markdown">
  Analysis found ${total.toFixed(1)} Mt across ${flows.length} voyages,
  peaking in ${maxYear}.
</script>
```

### Geospatial (DuckDB Spatial)

```sql
<script type="application/sql" database="../data/flows.duckdb" output="ports">
  SELECT port_name, ST_AsGeoJSON(geometry) as geojson, count(*) as visits
  FROM port_visits GROUP BY port_name, geometry
</script>
```

Use in Mapbox/Leaflet:
```javascript
ports.forEach(p => {
  const coords = JSON.parse(p.geojson).coordinates;
  new mapboxgl.Marker().setLngLat(coords).addTo(map);
});
```

## Critical Gotchas

1. **Data paths:** Use `../data/` from notebook, not `data/`
2. **SQL database path:** `database="../data/data.duckdb"` in SQL cells
3. **Display everything:** Use `display()` explicitly, don't rely on return values
4. **Cell IDs:** Must be unique across notebook
5. **Await FileAttachment:** All FileAttachment calls return promises
6. **Edit source:** Edit `docs/index.html`, not `docs/.observable/dist/`
7. **Auto-updating files:** `template.html` and `CLAUDE.md` download from `.github` repo on deploy
8. **Case-sensitive paths:** GitHub Pages is case-sensitive
9. **SQL cells at build time:** Database must exist when running `make build`

## Creating New Notebook

1. Use `data-desk-eco.github.io` as GitHub template
2. Enable Pages (Settings → Pages → Source: GitHub Actions)
3. Clone: `git clone [url] && cd [repo] && yarn`
4. Preview: `make preview`
5. Edit `docs/index.html`
6. Push - deploys to `https://research.datadesk.eco/[repo-name]/`

## Resources

- Observable Notebook Kit: https://observablehq.com/notebook-kit/
- Observable Plot: https://observablehq.com/plot/
- Observable Inputs: https://observablehq.com/notebook-kit/inputs
- DuckDB SQL: https://duckdb.org/docs/sql/introduction
- All Data Desk notebooks: https://research.datadesk.eco/

## Energy & Trade Flow Reference Sources

Authoritative public sources for validating analysis. Useful for context and sense-checking.

### Primary Reference Sources

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **IEA** | [iea.org/data-and-statistics](https://www.iea.org/data-and-statistics) | International Energy Agency - global energy balances, oil market reports | Global | Oil, gas, coal, renewables | Monthly/Annual | Free (limited) + Paid; Excel/PDF; No API |
| **EIA** | [eia.gov](https://www.eia.gov) | US Energy Information Administration - production, imports/exports, stocks | US + Global | Crude, products, LNG, coal | Weekly/Monthly | **Free**; API (JSON), Excel, CSV, bulk ZIP; Registration for API key |
| **UN Comtrade** | [comtradeplus.un.org](https://comtradeplus.un.org) | Global trade statistics by HS code | 200+ countries | All commodities (HS codes) | Monthly (2-3mo lag) | **Free**; API, CSV, JSON; No registration: 500 records/call; Free registration: 100k records/call |
| **Eurostat** | [ec.europa.eu/eurostat](https://ec.europa.eu/eurostat/web/energy/overview) | EU statistical office - energy balances, trade | EU-27 | Oil, gas, coal, electricity | Monthly | **Free**; API (SDMX), CSV, bulk download; No registration |
| **JODI** | [jodidata.org](https://www.jodidata.org) | Joint Organisations Data Initiative - oil/gas transparency | 100+ countries | Crude, products, natural gas | Monthly | **Free**; Online viewer, downloadable; No API |

### US Federal & State Sources

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **US DOE** | [energy.gov/data](https://www.energy.gov/data) | Dept of Energy - strategic reserves, policy data | US | SPR, all energy | Varies | **Free**; PDF, Excel |
| **US Census (Trade)** | [census.gov/foreign-trade](https://www.census.gov/foreign-trade/data) | Official US import/export statistics | US | All (HS/NAICS codes) | Monthly | **Free**; API, CSV, Excel; No registration |
| **USITC DataWeb** | [dataweb.usitc.gov](https://dataweb.usitc.gov) | US International Trade Commission - detailed HTS data | US | All (HTS codes) | Monthly | **Free**; CSV, Excel download; No registration |
| **Texas RRC** | [rrc.texas.gov](https://www.rrc.texas.gov/oil-and-gas/) | Texas Railroad Commission - production, permits | Texas | Crude, gas, NGL | Monthly | **Free**; Online queries, downloadable datasets |
| **Louisiana DNR** | [dnr.louisiana.gov](http://www.dnr.louisiana.gov/index.cfm/page/134) | LA Dept Natural Resources - production data | Louisiana | Crude, gas | Monthly | **Free**; PDF, online queries |
| **Louisiana SONRIS** | [sonris.com](https://sonris.com) | LA Strategic Online Natural Resources Info System | Louisiana | Crude, gas, wells | Daily/Monthly | **Free**; Online database, shapefiles |
| **California DOGGR** | [conservation.ca.gov/calgem](https://www.conservation.ca.gov/calgem) | CA Geologic Energy Management | California | Crude, gas | Monthly | **Free**; Online queries, downloads |
| **North Dakota DMR** | [dmr.nd.gov/oilgas](https://www.dmr.nd.gov/oilgas/) | ND Dept Mineral Resources (Bakken) | North Dakota | Crude, gas | Monthly | **Free**; Online queries, downloads |
| **Alaska AOGCC** | [aogcc.alaska.gov](https://www.aogcc.alaska.gov) | Alaska Oil & Gas Conservation Commission | Alaska | Crude, gas | Monthly | **Free**; Online database |
| **Wyoming OGCC** | [wogcc.wyo.gov](https://wogcc.wyo.gov) | Wyoming Oil & Gas Conservation Commission | Wyoming | Crude, gas | Monthly | **Free**; Online database (WYDE explorer) |

### International Government Sources

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **UK DESNZ** | [gov.uk/government/statistics](https://www.gov.uk/government/statistics/oil-and-oil-products-section-3-energy-trends) | UK Dept Energy Security - DUKES, Energy Trends | UK | Oil, gas, coal, power | Monthly/Annual | **Free**; Excel, ODS, PDF; No API |
| **UK HMRC Trade** | [uktradeinfo.com](https://www.uktradeinfo.com) | UK customs trade data | UK | All (CN codes) | Monthly | **Free**; API available, CSV; Open Govt Licence |
| **Statistics Canada** | [statcan.gc.ca](https://www.statcan.gc.ca/en/subjects-start/energy) | Canadian energy statistics | Canada | Crude, gas, products | Monthly | **Free**; API (JSON, CSV, XML); No registration |
| **CER (Canada)** | [cer-rec.gc.ca](https://www.cer-rec.gc.ca/en/data-analysis/energy-commodities/) | Canada Energy Regulator - pipelines, exports | Canada | Crude, gas, NGL | Monthly | **Free**; Online tools, downloadable |
| **ANP Brazil** | [gov.br/anp](https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-estatisticos) | Brazil National Petroleum Agency | Brazil | Crude, products, biofuels | Monthly | **Free**; Excel, PDF (Portuguese) |
| **Pemex (Mexico)** | [pemex.com/ri](https://www.pemex.com/ri/Publicaciones/Paginas/IndicadoresPetroleros.aspx) | Mexican state oil company statistics | Mexico | Crude, products | Monthly | **Free**; PDF, Excel (Spanish) |

### Producer/Exporter Sources

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **OPEC** | [opec.org/opec_web/en/data_graphs](https://www.opec.org/opec_web/en/data_graphs/40.htm) | OPEC Monthly Oil Market Report | OPEC members | Crude | Monthly | **Free**; PDF reports, online charts |
| **OPEC ASB** | [asb.opec.org](https://asb.opec.org) | Annual Statistical Bulletin - detailed data | OPEC + global | Crude, products, trade | Annual | **Free**; Interactive online, PDF |
| **Saudi Aramco** | [aramco.com/investors](https://www.aramco.com/en/investors) | Saudi production/export data | Saudi Arabia | Crude, products | Quarterly | **Free**; PDF reports |
| **Petrobras** | [petrobras.com.br/ri](https://www.petrobras.com.br/ri) | Brazilian NOC production/exports | Brazil | Crude, products | Monthly | **Free**; PDF, Excel |

### Shipping & Customs

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **Eurostat Comext** | [ec.europa.eu/eurostat/comext](https://ec.europa.eu/eurostat/web/international-trade-in-goods/overview) | EU external trade database | EU-27 | All (CN codes) | Monthly | **Free**; API, bulk download, CSV |
| **China Customs (GACC)** | [english.customs.gov.cn](http://english.customs.gov.cn) | China General Administration of Customs | China | All | Monthly | **Free**; PDF, limited English; Aggregated data |
| **India DGCIS** | [dgciskol.gov.in](https://www.dgciskol.gov.in) | India trade statistics | India | All | Monthly | Partial free; Some data requires purchase |

### LNG-Specific Sources

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **GIIGNL** | [giignl.org](https://giignl.org) | Intl Group of LNG Importers - annual report | Global | LNG | Annual | **Free**; PDF annual report |
| **FERC (US)** | [ferc.gov/industries-data/natural-gas/lng](https://www.ferc.gov/industries-data/natural-gas/lng) | US LNG export terminal data | US | LNG | Monthly | **Free**; PDF, Excel |
| **ICE ENDEX** | [theice.com/market-data](https://www.theice.com/market-data) | European gas hub prices/flows | Europe | Natural gas, LNG | Daily | Paid subscription for full data |

### Academic & Research Institutions

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **Columbia CGEP** | [energypolicy.columbia.edu](https://www.energypolicy.columbia.edu) | Center on Global Energy Policy - research, commentary, data | Global | Oil, gas, energy transition | Ongoing | **Free**; PDF reports, some datasets |
| **Oxford OIES** | [oxfordenergy.org](https://www.oxfordenergy.org) | Oxford Institute for Energy Studies - deep research papers | Global | Oil, gas, LNG, power | Ongoing | **Free**; PDF papers |

### Industry Analysis & Consulting

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **Wood Mackenzie** | [woodmac.com](https://www.woodmac.com) | In-depth upstream, downstream, energy transition analysis | Global | Oil, gas, LNG, power, metals | Ongoing | **Paid** (most content); Limited free insights |

### News & Market Commentary

| Source | Link | Description | Geography | Commodities | Frequency | Access |
|--------|------|-------------|-----------|-------------|-----------|--------|
| **Reuters Commodities** | [reuters.com/markets/commodities](https://www.reuters.com/markets/commodities/) | Breaking news, market moves, trade flow reporting | Global | Oil, gas, metals, agriculture | Real-time | **Free**; Online articles |
| **S&P Global Commodity Insights** | [spglobal.com/commodityinsights](https://www.spglobal.com/commodityinsights/en) | Platts pricing, market analysis, news | Global | Oil, gas, LNG, petrochemicals | Daily | Free (news) + Paid (pricing/data) |
