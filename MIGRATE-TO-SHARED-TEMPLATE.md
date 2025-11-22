# Migrate Notebook to Shared Template

This guide shows how to migrate a Data Desk notebook repository to use the shared `template.html` from `data-desk-eco.github.io`.

## Overview

Instead of maintaining `template.html` in each notebook repo, all notebooks now download the canonical version from `data-desk-eco.github.io` during the GitHub Actions build process.

**Benefits:**
- Single source of truth for styling and branding
- Update once, applies to all notebooks (after rebuild)
- Less maintenance per notebook repo

## Migration Steps

### 1. Add template.html to .gitignore

Edit `.gitignore` and add:

```
template.html
```

This prevents the downloaded template from being committed.

### 2. Update GitHub Actions Workflow

Find your workflow file (usually `.github/workflows/deploy.yml` or similar) and add the download step **before** the build step:

**Before:**
```yaml
- run: yarn --frozen-lockfile
- run: yarn build
```

**After:**
```yaml
- run: yarn --frozen-lockfile

- name: Download shared template
  run: git show origin/main:template.html > template.html
  env:
    GIT_TERMINAL_PROMPT: 0

- run: yarn build
```

### 3. Remove template.html from git tracking

Keep the file locally (for `yarn preview` to work), but remove it from git:

```bash
git rm --cached template.html
```

This removes it from git tracking while keeping the local file.

### 4. Commit and push

```bash
git add .gitignore .github/workflows/deploy.yml
git commit -m "Use shared template from data-desk-eco.github.io"
git push
```

### 5. Test

Push to main branch and verify:
1. GitHub Actions runs successfully
2. The workflow downloads template.html
3. The build completes without errors
4. The deployed site looks correct

## Local Development

For local preview (`yarn preview`), you have two options:

**Option 1: Keep template.html locally (recommended)**
- Keep your current `template.html` file
- It will be ignored by git (thanks to `.gitignore`)
- Gets overwritten when you run the workflow, but that's fine

**Option 2: Download manually when needed**
```bash
git show origin/main:template.html > template.html
```

## Updating to Latest Template

To pick up template changes from `data-desk-eco.github.io`:

1. Make a trivial commit or manually trigger the workflow
2. GitHub Actions will download the latest template
3. Your site rebuilds with the updated styling

Alternatively, for local testing:
```bash
git show origin/main:template.html > template.html
yarn build
```

## Troubleshooting

### "template.html not found" during local preview

Download the template:
```bash
git show origin/main:template.html > template.html
```

### Build fails in GitHub Actions

Check that:
- The download step comes **before** `yarn build`
- The `git show` command succeeded (check action logs)
- Your local repo has fetched the latest from origin (the workflow does `actions/checkout` which handles this)

### Want to customize the template for one notebook

If a notebook needs custom styling:
1. Keep a local `template.html` (committed)
2. Remove it from `.gitignore`
3. Skip the download step in the workflow
4. Document why in the README

The shared template approach is opt-in per repo.

## Reverting

To go back to a local template:

1. Remove `template.html` from `.gitignore`
2. Remove the download step from workflow
3. `git add template.html && git commit`

---

**Source template location:**
https://github.com/data-desk-eco/data-desk-eco.github.io/blob/main/template.html

**Questions?** Check the main repo's CLAUDE.md or open an issue.
