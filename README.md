# Data Desk research index

The index of every Data Desk research notebook, published at
[research.datadesk.eco](https://research.datadesk.eco/).

**To make a new notebook, use
[`notebook-template`](https://github.com/data-desk-eco/notebook-template), not
this repo** — or run `data-desk new <name>`. This repo used to double as the
template; it does not any more.

## How the index works

A GitHub Action runs monthly, or on push, and fetches every public
`data-desk-eco` repo that has Pages enabled and a non-empty description. `make
data` writes them to `data/data.duckdb` as a `projects` table; the notebook
queries that and lists them by most recently updated.

```bash
data-desk link    # shared build template and house rules
yarn
make preview      # http://localhost:3000
make data         # refresh the project list
make build
```

Built with Observable Notebook Kit and deployed via GitHub Actions.
