# Post-render script: generate a filtered RSS feed for R-bloggers
# Only includes posts tagged with the "r-bloggers" category

library(xml2)

site_dir <- "_site"
rss_in  <- file.path(site_dir, "index.xml")
rss_out <- file.path(site_dir, "r-bloggers.xml")

if (!file.exists(rss_in)) {
  message("RSS feed not found: ", rss_in)
  quit(save = "no", status = 0)
}

doc <- read_xml(rss_in)

# Extract item links and map to post slugs
items <- xml_find_all(doc, "//item")
links <- xml_text(xml_find_first(items, "link"))

# Check each post for the r-bloggers category in its YAML frontmatter
keep <- logical(length(links))
for (i in seq_along(links)) {
  # Extract slug from URL: .../posts/<slug>/
  slug <- sub(".*/posts/([^/]+)/.*", "\\1", links[i])
  qmd <- file.path("posts", slug, "index.qmd")

  if (file.exists(qmd)) {
    yaml_lines <- readLines(qmd, n = 20, warn = FALSE)
    # Find the categories line
    cat_line <- grep("^categories:", yaml_lines, value = TRUE)
    keep[i] <- length(cat_line) > 0 &&
               grepl("r-bloggers", cat_line, fixed = TRUE)
  }
}

if (!any(keep)) {
  message("No r-bloggers posts found; RSS not generated.")
  quit(save = "no", status = 0)
}

# Build filtered RSS: keep matching items, update channel title
ns <- xml_ns(doc)

# Remove items that don't match
xml_remove(items[!keep])

# Update channel title and description
channel <- xml_find_first(doc, "//channel")
channel_title <- xml_find_first(channel, "title")
channel_desc  <- xml_find_first(channel, "description")
xml_text(channel_title) <- "metabreeding (R-bloggers)"
xml_text(channel_desc)  <- "R-related posts from metabreeding"

# Update atom:link
atom_link <- xml_find_first(channel, "atom:link")
xml_set_attr(atom_link, "href", "https://luansheng.github.io/lsblog/r-bloggers.xml")

write_xml(doc, rss_out)
message("Filtered RSS written: ", rss_out, " (", sum(keep), " posts)")
