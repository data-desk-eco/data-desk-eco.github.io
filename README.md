# Data Desk Research Index

This repository serves two purposes:
1. The central index for all Data Desk research notebooks at [`https://research.datadesk.eco/`](https://research.datadesk.eco/)
2. A template for creating new research notebooks

## Creating a new research notebook

1. Use this repository as a template to create a new repo (the name becomes the URL)
2. Go to "Settings" → "Pages" → "Build and deployment" and select "GitHub Actions"
3. Clone your new repository and install dependencies: `yarn` (or `npm install`)
4. Run preview: `yarn preview`
5. Edit `docs/index.html` in your text editor or [Observable Desktop](https://observablehq.com/notebook-kit/desktop)
6. Commit and push - GitHub Actions will automatically deploy to `https://research.datadesk.eco/[repo-name]`

## How the index works

- A GitHub Action runs daily (or on push) to fetch all public repos with Pages enabled
- The `projects.json` file is generated with repo names, descriptions, and last-updated dates
- Projects are displayed sorted by most recently updated
- Built using [Observable Notebook Kit](https://observablehq.com/notebook-kit/kit) and deployed via GitHub Actions

<figure>
  <img width="1264" height="912" alt="Editing in Observable Desktop" src="https://github.com/user-attachments/assets/a4ba7acc-7251-44f5-a0b7-b4892b32448d" />
  <caption>Editing this notebook in Observable Desktop</caption>
</figure>
