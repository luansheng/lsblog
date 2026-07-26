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
