#!/usr/bin/env Rscript
# Figures for posts/plot-pedigree-comparison-20260824/
#  - six-panel comparison of pedigree plotting functions on a 30-animal
#    Hinterwald cattle pedigree, labels truncated to the last 4 ID digits
#  - one large visPedigree figure: a single 1995-born animal traced back
#    through thirteen generations to the founders (205 animals), generation
#    labels on the left
# Run from the repository root.

suppressMessages({
  library(optiSel)
  library(visPedigree)
})

outdir <- "posts/plot-pedigree-comparison-20260824"

## ---------------------------------------------------------------------------
## 1. The comparison pedigree
## ---------------------------------------------------------------------------
# The 30 animals shown in the original published figures: the 1995-born
# cohort of the Hinterwald cattle demo pedigree (optiSel::ExamplePed,
# 1,179 animals born 1947-1995), each traced two generations up with
# tidyped(trace = "up", tracegen = 2). Parents outside the traced set are
# coded as unknown -- the preparation the kinship2-family tools expect.
data("ExamplePed", package = "optiSel")
ped <- ExamplePed
ped$Indiv <- as.character(ped$Indiv)
ped$Sire  <- as.character(ped$Sire)
ped$Dam   <- as.character(ped$Dam)

svg_ids <- c(
  "276000802865772", "276000802884541", "276000802908050", "276000802908352",
  "276000802918062", "276000802918275", "276000802918439", "276000802918444",
  "276000802918674", "276000802918789", "276000802918869", "276000802918887",
  "276000802925350", "276000802925588", "276000802925591", "276000802925603",
  "276000802932018", "276000802932039", "276000802932206", "276000802932262",
  "276000802932609", "276000802938016", "276000802938230", "276000802940243",
  "276000802940621", "276000802947037", "276000802947493", "276000808591172",
  "276000808591205", "276000810087083"
)
ped30 <- ped[match(svg_ids, ped$Indiv), ]
stopifnot(nrow(ped30) == length(svg_ids))

ped30$Sire[!ped30$Sire %in% svg_ids] <- NA_character_
ped30$Dam[!ped30$Dam %in% svg_ids] <- NA_character_

n_both  <- sum(!is.na(ped30$Sire) & !is.na(ped30$Dam))
n_one   <- sum(xor(!is.na(ped30$Sire), !is.na(ped30$Dam)))
n_none  <- sum(is.na(ped30$Sire) & is.na(ped30$Dam))
n_na_sex <- sum(is.na(ped30$Sex))
message("pedigree: ", nrow(ped30), " animals; both parents in set: ", n_both,
        "; one: ", n_one, "; none: ", n_none, "; NA sex: ", n_na_sex, "\n")

short_id <- function(x) substr(x, nchar(x) - 3, nchar(x))
dup4 <- unique(short_id(ped30$Indiv)[duplicated(short_id(ped30$Indiv))])
if (length(dup4)) message("WARNING last-4 duplicates:", paste(dup4, collapse = ", "), "\n")

## ---------------------------------------------------------------------------
## 2. visPedigree
## ---------------------------------------------------------------------------
p30 <- data.frame(Ind  = ped30$Indiv,
                  Sire = ped30$Sire,
                  Dam  = ped30$Dam,
                  Sex  = ifelse(ped30$Sex == 1, "M",
                         ifelse(ped30$Sex == 2, "F", "U")))
tp <- tidyped(p30)
tp$ID4 <- short_id(tp$Ind)

tryCatch({
  visped(tp, labelvar = "ID4", showgraph = FALSE,
         file = file.path(outdir, "a_visped.svg"), cex = 0.9)
  message("a_visped.svg OK\n")
}, error = function(e) message("a_visped FAILED:", conditionMessage(e), "\n"))

## ---------------------------------------------------------------------------
## 3. kinship2
## ---------------------------------------------------------------------------
tryCatch({
  suppressMessages(library(kinship2))
  sex_num <- ifelse(is.na(ped30$Sex), 3, ped30$Sex)
  k2 <- with(ped30, pedigree(id = Indiv, dadid = Sire, momid = Dam, sex = sex_num,
                             missid = 0))
  svg(file.path(outdir, "b_kinship2.svg"), width = 8, height = 4.5)
  plot(k2, id = short_id(k2$id), cex = 0.9)
  dev.off()
  message("b_kinship2.svg OK\n")
}, error = function(e) message("b_kinship2 FAILED:", conditionMessage(e), "\n"))

## ---------------------------------------------------------------------------
## 4. ggpedigree
## ---------------------------------------------------------------------------
tryCatch({
  suppressMessages(library(ggpedigree))
  suppressMessages(library(svglite))
  d <- data.frame(personID = ped30$Indiv,
                  momID    = ped30$Dam,
                  dadID    = ped30$Sire,
                  famID    = NA_character_,
                  sex      = ifelse(is.na(ped30$Sex), NA_integer_, ped30$Sex),
                  spouseID = NA_character_)
  d$personID <- short_id(d$personID)
  d$momID    <- short_id(d$momID)
  d$dadID    <- short_id(d$dadID)
  g <- ggPedigree(d, interactive = FALSE)
  svglite::svglite(file.path(outdir, "c_ggpedigree.svg"), width = 8, height = 4.5)
  print(g)
  dev.off()
  message("c_ggpedigree.svg OK\n")
}, error = function(e) message("c_ggpedigree FAILED:", conditionMessage(e), "\n"))

## ---------------------------------------------------------------------------
## 5. pedtricks
## ---------------------------------------------------------------------------
tryCatch({
  suppressMessages(library(pedtricks))
  dt <- data.frame(id  = short_id(ped30$Indiv),
                   dam = short_id(ped30$Dam),
                   sire = short_id(ped30$Sire))
  sx <- ifelse(!is.na(ped30$Sex) & ped30$Sex == 1, 1L, 0L)
  svg(file.path(outdir, "d_pedtricks.svg"), width = 8, height = 4.5)
  draw_ped(dt, sex = sx, dotcol = c("black", "white"), cex = 0.9)
  dev.off()
  message("d_pedtricks.svg OK\n")
}, error = function(e) message("d_pedtricks FAILED:", conditionMessage(e), "\n"))

## ---------------------------------------------------------------------------
## 6. optiSel pedplot()
## ---------------------------------------------------------------------------
tryCatch({
  po <- ped30
  po$Sex <- ifelse(is.na(po$Sex), "female", ifelse(po$Sex == 1, "male", "female"))
  po$Indiv <- short_id(po$Indiv)
  po$Sire  <- short_id(po$Sire)
  po$Dam   <- short_id(po$Dam)
  svg(file.path(outdir, "e_pedplot.svg"), width = 8, height = 4.5)
  pedplot(po)
  dev.off()
  message("e_pedplot.svg OK\n")
}, error = function(e) message("e_pedplot FAILED:", conditionMessage(e), "\n"))

## ---------------------------------------------------------------------------
## 7. Pedixplorer
## ---------------------------------------------------------------------------
tryCatch({
  suppressMessages(library(Pedixplorer))
  pd <- data.frame(id    = short_id(ped30$Indiv),
                   dadid = ifelse(is.na(ped30$Sire), 0, short_id(ped30$Sire)),
                   momid = ifelse(is.na(ped30$Dam), 0, short_id(ped30$Dam)),
                   sex   = ifelse(is.na(ped30$Sex), 0L, ped30$Sex),
                   famid = rep("F1", nrow(ped30)))
  P <- Pedigree(pd)
  svg(file.path(outdir, "f_pedixplorer.svg"), width = 8, height = 4.5)
  plot(P)
  dev.off()
  message("f_pedixplorer.svg OK\n")
}, error = function(e) message("f_pedixplorer FAILED:", conditionMessage(e), "\n"))

## ---------------------------------------------------------------------------
## 8. Deep visPedigree figure: one individual traced back to the founders
## ---------------------------------------------------------------------------
# ExamplePed records an unknown parent as the animal's own ID with a role
# prefix ("S" for sires, "D" for dams) and carries a placeholder founder row
# for each such reference (101 of them). Before tracing, recode those
# references as missing and drop the placeholder rows.
ped8 <- ped
ped8$Sire[ped8$Sire == paste0("S", ped8$Indiv)] <- NA_character_
ped8$Dam[ped8$Dam == paste0("D", ped8$Indiv)] <- NA_character_
ped8 <- ped8[!grepl("^[SD]", ped8$Indiv), ]

focal <- "276000808519445"   # a 1995-born Hinterwald animal
tp2 <- tidyped(ped8, cand = focal, trace = "up", tracegen = 20)
# labels show the last four digits (two suffixes repeat within the trace)
tp2$ID4 <- substr(tp2$Ind, nchar(tp2$Ind) - 3, nchar(tp2$Ind))
dup4 <- unique(tp2$ID4[duplicated(tp2$ID4)])
if (length(dup4)) message("NOTE last-4 duplicates: ", paste(dup4, collapse = ", "), "\n")
message("Deep trace: ", nrow(tp2), " animals, ", max(tp2$Gen),
        " generation levels, labels = last 4 digits\n")
visped(tp2, labelvar = "ID4", genlab = TRUE,
       showgraph = FALSE, file = file.path(outdir, "g_visped_deep.svg"),
       cex = 0.35, symbolsize = 0.6)
message("g_visped_deep.svg OK\n")

message("Done.\n")
