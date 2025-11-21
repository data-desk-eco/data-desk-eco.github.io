# Data Desk Research Notebooks

Data Desk produces investigative research and analysis on the global oil and gas industry for NGOs, think tanks, and media organizations. We publish our work as interactive research notebooks using Observable Notebook Kit 2.0.

## What Are Observable Notebooks?

Observable notebooks are not traditional Jupyter notebooks. They are standalone HTML pages with embedded JavaScript that compile to static sites. Each notebook is a single `index.html` file in the `docs/` directory that uses a custom `<notebook>` element to organize content into cells.

### Basic Structure

```html
<!doctype html>
<notebook theme="midnight">
  <title>Research Title</title>

  <script id="header" type="text/markdown">
    # Main Heading
    *Date*
  </script>

  <script id="data-loading" type="module">
    const data = await FileAttachment("data/flows.csv").csv({typed: true});
    display(Inputs.table(data));
  </script>
</notebook>
```

**Key points:**
- Each `<script>` tag is a cell with a unique `id` attribute
- Use `type="text/markdown"` for markdown cells
- Use `type="module"` for JavaScript cells
- Use `type="text/html"` for raw HTML cells
- Use `type="application/sql"` for SQL cells that query DuckDB databases

### Cell Execution Model

Unlike Jupyter notebooks that run sequentially, Observable notebooks use reactive execution:
- Cells automatically re-run when their dependencies change
- Variables defined in one cell are available to all other cells
- Use `display()` to explicitly render outputs (don't rely on return values)
- All cells are `type="module"` by default, giving you ES6 module syntax

## Working with Data

### FileAttachment API

Load data files from the `docs/` directory:

```javascript
// CSV with automatic type inference
const flows = await FileAttachment("data/flows.csv").csv({typed: true});

// JSON
const projects = await FileAttachment("projects.json").json();

// Parquet (efficient for large datasets)
const tracks = await FileAttachment("data/tracks.parquet").parquet();

// Images
const img = await FileAttachment("assets/photo.jpg").url();
```

**Important:**
- All paths are relative to the notebook HTML file location
- Data files must live in `docs/` or subdirectories
- Use forward slashes even on Windows
- Always `await` FileAttachment calls - they return promises

**Supported formats:** CSV, TSV, JSON, Parquet, Arrow, SQLite, DuckDB, ZIP, images, and more.

### DuckDB Integration

Observable Notebook Kit includes built-in DuckDB support for SQL queries. This is one of the most powerful features for data analysis.

#### SQL Cells

SQL cells query DuckDB databases directly:

```html
<script id="flows" output="flows" type="application/sql" database="data/flows.duckdb" hidden>
  select *
  from flows
  order by loading_date desc
</script>
```

**SQL cell attributes:**
- `type="application/sql"` - marks this as a SQL query
- `database="path/to/file.duckdb"` - path to DuckDB database file
- `output="flows"` - variable name to store results (accessible in other cells)
- `hidden` - don't display output (optional)
- `id` - unique identifier for the cell

The query results become available as a JavaScript variable with the name specified in `output`:

```javascript
// Use the results from the SQL cell above
display(html`<p>Found ${flows.length} flows</p>`);
display(Inputs.table(flows));
```

#### DuckDB Client

For more complex queries, use `DuckDBClient.of()`:

```javascript
const db = DuckDBClient.of();

// Query returns an array of objects
const summary = await db.query(`
  select
    year,
    count(*) as flow_count,
    sum(volume_kt) as total_volume
  from flows
  group by year
  order by year
`);

display(Inputs.table(summary));
```

#### DuckDB Setup Boilerplate

Some notebooks include this boilerplate for compatibility:

```javascript
<script id="database-setup" type="module">
  // Should be able to remove this in future versions of Notebook Kit
  const db = DuckDBClient.of();
</script>
```

This initializes DuckDB for notebooks that use SQL cells. It may not be needed in newer versions.

### ETL Patterns

Many research notebooks use a two-stage data pipeline:

**Stage 1: Data preparation (outside the notebook)**
- Located in `etl/` directory (dbt + DuckDB is common)
- Processes raw data from APIs, spreadsheets, AIS feeds, etc.
- Outputs clean DuckDB databases or CSV files to `docs/data/`
- Example: `46026b7e69d1df26536300f654ce80e2` uses dbt models to process 71,000 AIS positions into 762 validated cargo flows

**Stage 2: Analysis and visualization (in the notebook)**
- Load prepared data via FileAttachment or SQL cells
- Transform and aggregate using JavaScript/SQL
- Create visualizations with Observable Plot
- Generate interactive tables with Inputs

**Why this pattern?**
- Heavy data processing happens once, not every time the notebook loads
- Raw data sources can require credentials (LSEG API, Planet satellite imagery)
- dbt provides SQL-based transformations with testing and documentation
- DuckDB handles complex geospatial queries and large datasets efficiently
- Compiled notebooks remain fast and don't need external dependencies

## Visualization

### Observable Plot

Observable Plot is the recommended charting library (built into Notebook Kit):

```javascript
// Bar chart with stacking
display(Plot.plot({
  title: "Annual volumes by destination",
  width: 928,
  height: 400,
  x: { label: "Year" },
  y: { label: "Volume (Mt)", grid: true },
  color: {
    legend: true,
    domain: ["Europe", "Asia"],
    range: ["#74c0fc", "#f8f9fa"]
  },
  marks: [
    Plot.barY(data, {
      x: "year",
      y: "volume",
      fill: "continent",
      tip: true
    }),
    Plot.ruleY([0])
  ]
}));

// Line chart
display(Plot.plot({
  marks: [
    Plot.line(timeseries, {
      x: "date",
      y: "value",
      stroke: "#74c0fc"
    })
  ]
}));

// Area chart with stacking
display(Plot.plot({
  marks: [
    Plot.areaY(data, {
      x: "date",
      y: "volume",
      fill: "destination",
      curve: "step-after"
    })
  ]
}));
```

**Plot features:**
- Automatic scales and axes
- Built-in tooltips with `tip: true`
- Responsive by default
- Great for time series, distributions, correlations
- Documentation: https://observablehq.com/plot/

### Interactive Inputs

Use `Inputs` for user controls:

```javascript
// Toggle
const show_all = view(Inputs.toggle({label: "Show all columns", value: false}));

// Search box
const searched = view(Inputs.search(data));

// Table with search
display(Inputs.table(searched, {
  rows: 25,
  columns: show_all ? undefined : ["name", "date", "value"]
}));

// Slider
const threshold = view(Inputs.range([0, 100], {step: 1, value: 50}));

// Select dropdown
const country = view(Inputs.select(["UK", "Norway", "Sweden"]));
```

The `view()` function makes the input value reactive - other cells automatically update when it changes.

### External Libraries

#### Mapbox GL JS

For interactive maps (example from `afungi-logistics`):

```html
<!-- Load CSS in a cell -->
<script id="mapbox-css" type="text/html">
  <link href="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css" rel="stylesheet" />
</script>

<!-- Load and use the library -->
<script id="map" type="module">
  // Load the script
  const script = document.createElement('script');
  script.src = 'https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js';
  script.onload = () => initMap();
  document.head.appendChild(script);

  function initMap() {
    window.mapboxgl.accessToken = 'pk.eyJ1...';
    const map = new window.mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/dark-v11',
      center: [40.4, -11.6],
      zoom: 8
    });
  }
</script>

<!-- Container for the map -->
<script id="map-container" type="text/html">
  <div id="map" style="height: 500px; width: 100%;"></div>
</script>
```

#### Other Libraries

- **D3**: Available via `require()` or dynamic imports
- **Leaflet**: Alternative to Mapbox for maps
- **Arquero**: Data wrangling (DataFrame-like API)
- Any npm package via dynamic `import()` or `require()`

## Development Workflow

### Setup

```bash
# Clone a notebook repository
git clone https://github.com/data-desk-eco/[repo-name]
cd [repo-name]

# Install dependencies (use yarn preferred)
yarn                      # or: npm install

# Preview with hot reload
yarn preview              # or: npm run preview

# Build for production
yarn build                # or: npm run build
```

### Local Preview

The preview server runs at `http://localhost:3000` with:
- Hot reload on file changes
- Same template as production
- Faster iteration than building

**Editing workflow:**
1. Open `docs/index.html` in your editor
2. Run `yarn preview`
3. Edit and save - changes appear immediately
4. Check browser console for errors

### Building

The build process:
1. Parses the `<notebook>` element and its cells
2. Compiles JavaScript cells into modules
3. Bundles dependencies (Plot, DuckDB, etc.)
4. Applies the custom template (`template.html`)
5. Outputs to `docs/.observable/dist/`

**Build command:**
```bash
notebooks build --root docs --template template.html -- docs/*.html
```

**What gets generated:**
- `docs/.observable/dist/index.html` - complete standalone page
- `docs/.observable/dist/assets/` - bundled JavaScript and CSS
- Copies of data files referenced by the notebook

**Important:** The dist folder is gitignored. The source is `docs/index.html`, not the built output.

### Deployment

All Data Desk notebooks use GitHub Actions for deployment:

```yaml
# .github/workflows/deploy.yml
- name: Build notebook
  run: yarn build

- name: Upload to Pages
  uses: actions/upload-pages-artifact@v3
  with:
    path: docs/.observable/dist
```

The workflow:
1. Triggers on push to main
2. Installs dependencies
3. Runs the build
4. Uploads `docs/.observable/dist` as artifact
5. Deploys to GitHub Pages

**GitHub Pages setup:**
- Settings → Pages → Source: GitHub Actions
- Custom domain: `research.datadesk.eco`
- Each repo becomes a subdirectory (e.g., `/46026b7e69d1df26536300f654ce80e2/`)

## Template Customization

The `template.html` file wraps the compiled notebook:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style type="text/css">
      @import url("observable:styles/index.css");
      @import url("https://rsms.me/inter/inter.css");

      :root {
        font-family: Inter, sans-serif;
      }

      /* Custom styles... */
    </style>
  </head>
  <body>
    <main>
      <!-- Logo, branding -->
    </main>
    <hr>
    <p id="footer">
      <!-- Footer content -->
    </p>
  </body>
</html>
```

**Data Desk template features:**
- Inter font family for clean typography
- Midnight theme for dark mode aesthetic
- Data Desk logo in header
- Custom list styling (using `>` instead of bullets)
- Footer with organization description and Observable attribution

**Customizing:**
- Edit `template.html` in your repo
- Changes apply to all notebooks in that repo
- Use `observable:styles/index.css` to import base styles
- Custom CSS overrides notebook defaults

## Common Patterns

### Data Aggregation

```javascript
// Group by and sum using d3.rollup
const annualTotals = d3.rollup(
  flows,
  v => d3.sum(v, d => d.volume),
  d => d.year
);

// Convert Map to array
const data = Array.from(annualTotals, ([year, volume]) => ({
  year,
  volume
})).sort((a, b) => a.year - b.year);
```

### Formatting

```javascript
// Date formatting
const formatDate = d3.utcFormat("%B %Y");
formatDate(new Date("2025-01-15")); // "January 2025"

// Number formatting
const formatNumber = d3.format(",.1f");
formatNumber(1234.567); // "1,234.6"

// Currency
const formatCurrency = d3.format("$,.0f");
formatCurrency(1234567); // "$1,234,567"
```

### Inline Calculations for Narrative

```javascript
// Calculate stats in a cell
const total = d3.sum(flows, d => d.volume);
const average = d3.mean(flows, d => d.volume);
const maxYear = d3.max(flows, d => d.year);
```

Then reference in markdown:

```html
<script type="text/markdown">
  Our analysis found ${total.toFixed(1)} Mt shipped across ${flows.length}
  voyages, peaking in ${maxYear} with an average of ${average.toFixed(1)} Mt
  per year.
</script>
```

### Conditional Display

```javascript
const show_details = view(Inputs.toggle({label: "Show details"}));

display(Inputs.table(data, {
  columns: show_details
    ? undefined  // all columns
    : ["name", "date", "value"]  // subset
}));
```

### Multi-way Joins

```javascript
// Join two datasets
const enriched = flows.map(f => ({
  ...f,
  vessel_name: vessels.find(v => v.imo === f.vessel_imo)?.name
}));

// Or use arquero for DataFrame-style operations
const joined = aq.table(flows)
  .join(aq.table(vessels), "vessel_imo", "imo")
  .select("loading_date", "vessel_name", "volume")
  .objects();
```

## Debugging

### Common Issues

**"FileAttachment is not defined"**
- FileAttachment is available in `type="module"` cells only
- Make sure your cell has `type="module"`, not `type="text/javascript"`

**Data not loading**
- Check file path is relative to `docs/index.html`
- Verify file exists in `docs/` directory
- Check browser network tab for 404 errors
- Ensure filename case matches (case-sensitive on Linux/GitHub)

**Plot not rendering**
- Did you `display()` the plot?
- Check browser console for JavaScript errors
- Verify data structure matches plot spec
- Try wrapping in try/catch to see error messages

**SQL cell returns empty results**
- Verify database file exists at specified path
- Check table name spelling
- Test query in DuckDB CLI first
- Ensure database file is in `docs/data/` not root

**Template not applied**
- Verify `--template template.html` in build command
- Check template file exists in repo root
- Look for syntax errors in template HTML

**Preview works but build fails**
- Check for absolute paths in FileAttachment (should be relative)
- Look for references to `/data/` instead of `data/`
- Test build locally before pushing

### Debugging SQL

Use DuckDB CLI to test queries:

```bash
duckdb docs/data/flows.duckdb

D SELECT count(*) FROM flows;
D .schema flows
D .tables
```

### Browser Console

Open browser dev tools (F12) to see:
- JavaScript errors
- Network requests for data files
- Variable values via console.log()
- Live values of notebook cells

## Performance

### Large Datasets

**Strategies:**
- Use Parquet instead of CSV (10-100x smaller, faster)
- Pre-aggregate data in ETL pipeline, not in notebook
- Store data in DuckDB and query subsets via SQL cells
- Use `Inputs.table()` pagination (default 25 rows)
- Consider streaming for very large datasets

**Example:**
```javascript
// Instead of loading 1M rows:
// const all = await FileAttachment("huge.csv").csv();

// Load aggregated subset:
const summary = await db.query(`
  SELECT year, month, sum(value) as total
  FROM huge_table
  GROUP BY year, month
`);
```

### Build Time

**Optimization:**
- Minimize external library imports
- Use SQL cells instead of loading full datasets
- Enable code splitting for large notebooks
- Avoid large images (compress/resize before adding)

**Typical build times:**
- Simple notebook: 2-5 seconds
- With DuckDB queries: 5-10 seconds
- Complex with maps/images: 10-20 seconds

## Repository Structure

Standard layout for Data Desk research notebooks:

```
research-notebook/
├── .github/
│   └── workflows/
│       └── deploy.yml           # GitHub Actions deployment
├── docs/
│   ├── index.html               # Notebook source (EDIT THIS)
│   ├── data/                    # Data files
│   │   ├── flows.csv
│   │   ├── flows.duckdb
│   │   └── vessels.json
│   ├── assets/                  # Images, screenshots
│   │   └── photo.jpg
│   └── .observable/
│       └── dist/                # Built output (gitignored)
├── etl/                         # Optional: data processing
│   ├── models/                  # dbt models (SQL)
│   ├── seeds/                   # Reference data (CSV)
│   └── dbt_project.yml
├── template.html                # Custom HTML wrapper
├── package.json                 # Dependencies and scripts
├── .gitignore
├── README.md                    # GitHub repo description
└── CLAUDE.md                    # This file
```

**What to commit:**
- `docs/index.html` (source)
- `docs/data/*` (processed data)
- `docs/assets/*` (images)
- `etl/*` (data pipeline)
- `template.html`
- `package.json`

**What NOT to commit:**
- `docs/.observable/dist/` (built output)
- `node_modules/`
- `.env` (credentials)
- Raw data files (keep in ETL, export processed to docs/data/)

## Creating a New Notebook

### From Template

1. Use `data-desk-eco.github.io` as GitHub template
2. Name repo (becomes URL slug)
3. Enable GitHub Pages (Settings → Pages → Source: GitHub Actions)
4. Clone and install: `git clone [url] && cd [repo] && yarn`

### Minimal Notebook

```html
<!doctype html>
<notebook theme="midnight">
  <title>My Research</title>

  <script type="text/markdown">
    # My Research

    This notebook analyzes...
  </script>

  <script type="module">
    const data = await FileAttachment("data.csv").csv({typed: true});
    display(Inputs.table(data));
  </script>
</notebook>
```

Save as `docs/index.html`, add `data.csv` to `docs/`, then `yarn preview`.

### Recommended Steps

1. **Plan the narrative:** What story does the data tell?
2. **Prepare data:** ETL pipeline to clean/aggregate (if needed)
3. **Structure cells:** Alternate markdown (narrative) and code (analysis)
4. **Add visualizations:** Start simple (tables), add charts as needed
5. **Test locally:** Preview and iterate quickly
6. **Build and deploy:** Push to GitHub, Actions handles deployment

## Advanced Topics

### Geospatial Analysis

DuckDB has spatial extension built-in:

```sql
<script type="application/sql" database="data/flows.duckdb" output="ports">
  SELECT
    port_name,
    ST_AsGeoJSON(geometry) as geojson,
    count(*) as visit_count
  FROM port_visits
  GROUP BY port_name, geometry
</script>
```

Use results in Mapbox/Leaflet:

```javascript
ports.forEach(port => {
  const coords = JSON.parse(port.geojson).coordinates;
  new mapboxgl.Marker()
    .setLngLat(coords)
    .setPopup(new mapboxgl.Popup().setText(port.port_name))
    .addTo(map);
});
```

### Time Series

```javascript
// Resample daily data to monthly
const monthly = d3.rollup(
  daily_data,
  v => d3.mean(v, d => d.value),
  d => d3.utcMonth(d.date)
);

// Calculate moving average
function movingAverage(data, window) {
  return data.map((d, i) => {
    const slice = data.slice(Math.max(0, i - window + 1), i + 1);
    return {
      ...d,
      ma: d3.mean(slice, x => x.value)
    };
  });
}
```

### Complex Transformations

For heavy data wrangling, use Arquero:

```javascript
import * as aq from "npm:arquero";

const summary = aq.table(flows)
  .filter(d => d.year >= 2020)
  .groupby("destination", "year")
  .rollup({
    count: d => op.count(),
    total: d => op.sum(d.volume),
    avg: d => op.mean(d.volume)
  })
  .orderby("year", "destination")
  .objects();

display(Inputs.table(summary));
```

### Multiple Notebooks

For large projects, split into multiple notebooks:

```
docs/
├── index.html           # Overview
├── methodology.html     # Methods
├── findings.html        # Results
└── data/                # Shared data
```

Build all notebooks:
```bash
notebooks build --root docs --template template.html -- docs/*.html
```

Link between notebooks:
```html
<script type="text/markdown">
  See our [methodology](methodology.html) for details.
</script>
```

## Resources

### Documentation

- **Observable Notebook Kit:** https://observablehq.com/notebook-kit/
- **Observable Plot:** https://observablehq.com/plot/
- **Observable Inputs:** https://observablehq.com/notebook-kit/inputs
- **FileAttachment API:** https://observablehq.com/notebook-kit/files
- **Observable stdlib:** https://github.com/observablehq/stdlib
- **DuckDB SQL:** https://duckdb.org/docs/sql/introduction
- **Observable Desktop:** https://observablehq.com/notebook-kit/desktop (visual editor)

### Examples

All Data Desk notebooks are open source:

- **INEOS ethane:** `/46026b7e69d1df26536300f654ce80e2/` - Complex ETL with dbt + DuckDB, SQL cells, stacked charts
- **Mozambique LNG:** `/afungi-logistics/` - ADS-B flight tracking, 3D Mapbox visualization, GeoJSON
- **Palma Bay:** `/palma-bay-dredging/` - Satellite imagery, marine AIS data, environmental analysis
- **Media:** `/media/` - Simpler structure, good starting point

Browse at https://research.datadesk.eco/

### Getting Help

- Observable Discord: https://observablehq.com/slack-invite (active community)
- GitHub Issues: https://github.com/observablehq/notebook-kit/issues
- Stack Overflow: Tag `observablehq`

## Tips for AI Agents

When working with Observable Notebooks:

1. **Always preview before building:** Use `yarn preview` for rapid iteration
2. **Data files in docs/:** FileAttachment paths are relative to `docs/index.html`
3. **SQL cells are powerful:** Use them to query DuckDB databases directly
4. **Display everything:** Don't return values, use `display()` explicitly
5. **Cell types matter:** `type="module"` for JavaScript, `type="text/markdown"` for markdown, `type="application/sql"` for SQL
6. **Observable stdlib is global:** `html`, `svg`, `FileAttachment`, `display` available everywhere
7. **Async is required:** Always `await` FileAttachment and database queries
8. **Built output is generated:** Don't edit `docs/.observable/dist/`, edit `docs/index.html`
9. **Template wraps notebook:** Custom styles and branding come from `template.html`
10. **ETL separate from notebook:** Heavy processing in `etl/`, analysis in notebook
11. **Test queries in DuckDB CLI:** Faster than debugging in notebook
12. **Use browser console:** Check for JavaScript errors and inspect variables
13. **Relative paths only:** No absolute paths in FileAttachment calls
14. **Observable Plot first:** Start with Plot before reaching for D3
15. **Reactivity is automatic:** Variables update when dependencies change

## Project-Specific Notes

This repository (`data-desk-eco.github.io`) serves as the central index at `https://research.datadesk.eco/`. It:
- Aggregates all Data Desk notebooks via GitHub API
- Auto-updates daily via GitHub Actions
- Also functions as a template for new notebooks

To add a new project to the index:
- Create repo in `data-desk-eco` org
- Enable GitHub Pages (Actions)
- Add description (shows in index)
- It will appear automatically within 24 hours
