# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A [Quarto](https://quarto.org/) blog about animal breeding and quantitative genetics, written by Professor Sheng Luan. Published to GitHub Pages at `https://luansheng.github.io/lsblog`.

## Commands

### Preview locally

```bash
quarto preview
```

### Render (full site, refreshing cached outputs)

```bash
quarto render --cache-refresh
```

### Render a single post

```bash
quarto render posts/<post-dir>/index.qmd --cache-refresh
```

### Publish to GitHub Pages

```bash
printf 'Y\n' | quarto publish gh-pages
```

Or use the bundled safe-publish script (render + publish in one step):

```bash
bash scripts/publish-gh-pages-safe.sh                     # full site
bash scripts/publish-gh-pages-safe.sh posts/<dir>/index.qmd  # single post
```

### Update the Publication page (auto-maintained)

`publication.qmd` is **generated** — never edit it by hand. The pipeline:

1. `publications.json` is the database: `auto` entries (English papers where Sheng Luan is first or last/corresponding author, pulled from the OpenAlex author profile `A5040332583`) and `manual` entries (Chinese-language papers and non-first/corresponding papers, kept verbatim in `display`).
2. `scripts/update_publications.py` (Python stdlib only) fetches the OpenAlex profile, filters by venue whitelist + first/last author position, merges new works by DOI, takes author names from Crossref (publisher-registered; OpenAlex display names only as fallback), and regenerates `publication.qmd` sorted by year.
3. `.github/workflows/update-publications.yml` runs it weekly (Mon 03:17 UTC) and commits changes to `main`. Publishing to GitHub Pages stays manual (see above).

Manual edits go into `publications.json`, not the qmd:

- **Add a Chinese paper**: append to `manual` with `display` (markdown text), `year`, and a new `order`.
- **Suppress a wrongly auto-added paper**: add its DOI to `filter.suppressed` in `publications.json`.
- **Guarantee a paper is included** (e.g. the visPedigree software paper in *Bioinformatics Advances*, which is outside the venue whitelist and may sit in a freshly split OpenAlex author cluster): add its DOI to `filter.watch_dois` — venue checks are bypassed, the first/last-author rule still applies, and the author is matched by name.
- **Chinese papers with English-translated OpenAlex records** (CNKI DOIs like `10.3724/...`): put the DOI in the manual entry's `suppress_dois` to prevent an English duplicate.

Run locally with `python3 scripts/update_publications.py` (exit code 2 = changes made).

## Architecture

### Post structure

Each post lives in `posts/<slug>/` as `index.qmd`. Posts use Quarto's [freeze](https://quarto.org/docs/projects/code-execution.html#freeze) feature (`posts/_metadata.yml` sets `freeze: true`), which caches computational outputs in `_freeze/`. Example post layout:

```
posts/million_ped-20260324/
  index.qmd          # Quarto markdown with R code chunks
  data.csv           # Optional attached data files
  image.png          # Optional cover / inline images
  index_cache/       # R cache (gitignored)
  index_files/       # Rendering intermediates (gitignored)
```

### Publishing and the freeze trap

`posts/_metadata.yml` sets `freeze: true` for all posts. This means `quarto publish gh-pages` **reuses previously frozen execution results** — if a post's R code, figures, or sampling outputs changed, the published page will still show the old results.

See `PUBLISH-SOP.md` for the full decision tree. The critical rule is:

> When code, figures, random sampling, or data outputs change, run `quarto render --cache-refresh` **before** `quarto publish gh-pages`. Text-only changes can publish directly.

### Post frontmatter conventions

Posts use categories (e.g., `Breeding`, `Pedigree Analysis`, `visPedigree`, `R`, `code`, `AI`), descriptions, and optional TOC. Code-heavy posts typically disable warnings/messages in YAML:

```yaml
execute:
  warning: false
  message: false
```

### Git

- **Source branch**: `main` — all writing and editing happens here
- **Publish branch**: `gh-pages` — managed by `quarto publish`, never edited directly
- **Ignored**: `_site/`, `_freeze/`, `.quarto/`, `*_files/`, `*_cache/`, and large CSV data files tracked outside git

### R package dependency

Several posts use the [visPedigree](https://github.com/luansheng/visPedigree) R package (also authored by the blog owner) for pedigree analysis and visualization. Posts that run R code require the package and its dependencies installed in the local R environment.

### Theme

Uses [simplex](https://bootswatch.com/simplex/) Bootswatch theme with a custom brand override and `styles.css` for additional CSS.
