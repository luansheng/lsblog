#!/usr/bin/env Rscript
# Timings for posts/plot-pedigree-comparison-20260824/index.qmd
#
# Protocol: one warm-up call, five timed repetitions, median reported.
# Each package's plot call is timed inside a null PDF device, so layout
# computation is included and disk rendering is excluded; data and pedigree
# objects are prepared once, outside the timed region.
#
# Usage:
#   Rscript scripts/plot-pedigree-timings.R            # 30-animal pedigree (~2 min)
#   Rscript scripts/plot-pedigree-timings.R full       # + 1,179-animal pedigree (~20 min)
#
# The 1,179-animal column in the article was measured with this script;
# re-running it on a differently loaded machine can shift the medians
# slightly. Pedixplorer's default label auto-scaling declines to render at
# that size, so a small cex is set for it (see the article).

args <- commandArgs(trailingOnly = TRUE)
DO_FULL <- length(args) == 1 && args[1] == "full"

suppressMessages({
  library(optiSel)
  library(visPedigree)
  library(kinship2)
  library(ggpedigree)
  library(pedtricks)
  library(Pedixplorer)
  library(purgeR)
})

data("ExamplePed", package = "optiSel")
ped <- ExamplePed
ped$Indiv <- as.character(ped$Indiv)
ped$Sire  <- as.character(ped$Sire)
ped$Dam   <- as.character(ped$Dam)

# ExamplePed records an unknown parent as the animal's own ID with a role
# prefix ("S" for sires, "D" for dams) plus a placeholder founder row for
# each such reference. The timings below use the data as distributed
# (1,179 rows), as the article does -- the kinship2-family completeness
# checks pass on it unmodified.

short_id <- function(x) substr(x, nchar(x) - 3, nchar(x))

med <- function(f, reps = 5) {
  f()  # warm-up
  median(replicate(reps, system.time(f())[["elapsed"]]))
}

## ---- the 30-animal comparison pedigree ------------------------------------
ids30 <- c(
  "276000802865772", "276000802884541", "276000802908050", "276000802908352",
  "276000802918062", "276000802918275", "276000802918439", "276000802918444",
  "276000802918674", "276000802918789", "276000802918869", "276000802918887",
  "276000802925350", "276000802925588", "276000802925591", "276000802925603",
  "276000802932018", "276000802932039", "276000802932206", "276000802932262",
  "276000802932609", "276000802938016", "276000802938230", "276000802940243",
  "276000802940621", "276000802947037", "276000802947493", "276000808591172",
  "276000808591205", "276000810087083"
)
ped30 <- ped[match(ids30, ped$Indiv), ]
ped30$Sire[!ped30$Sire %in% ids30] <- NA
ped30$Dam[!ped30$Dam %in% ids30] <- NA
stopifnot(nrow(ped30) == length(ids30))

## ---- objects prepared once, outside the timed region ----------------------
# 30-animal pedigree: labels truncated to the last 4 digits (as in the figures)
tp30 <- tidyped(ped30)
tp30$ID4 <- short_id(tp30$Ind)
k30 <- with(ped30, pedigree(id = Indiv, dadid = Sire, momid = Dam,
                            sex = ifelse(is.na(Sex), 3, Sex), missid = 0))
d30 <- data.frame(personID = short_id(ped30$Indiv),
                  momID    = short_id(ped30$Dam),
                  dadID    = short_id(ped30$Sire),
                  famID    = NA_character_,
                  sex      = ifelse(is.na(ped30$Sex), NA_integer_, ped30$Sex),
                  spouseID = NA_character_)
dt30 <- data.frame(id   = short_id(ped30$Indiv),
                   dam  = short_id(ped30$Dam),
                   sire = short_id(ped30$Sire))
sx30 <- ifelse(!is.na(ped30$Sex) & ped30$Sex == 1, 1L, 0L)
po30 <- ped30
po30$Sex <- ifelse(is.na(po30$Sex), "female", ifelse(po30$Sex == 1, "male", "female"))
po30$Indiv <- short_id(po30$Indiv)
po30$Sire  <- short_id(po30$Sire)
po30$Dam   <- short_id(po30$Dam)
pd30 <- data.frame(id    = short_id(ped30$Indiv),
                   dadid = ifelse(is.na(ped30$Sire), 0, short_id(ped30$Sire)),
                   momid = ifelse(is.na(ped30$Dam), 0, short_id(ped30$Dam)),
                   sex   = ifelse(is.na(ped30$Sex), 0L, ped30$Sex),
                   famid = rep("F1", nrow(ped30)))
P30 <- Pedigree(pd30)

# 1,179-animal pedigree: full 15-digit IDs (truncation would collide)
tpfull <- tidyped(ped)
kfull <- with(ped, pedigree(id = Indiv, dadid = Sire, momid = Dam,
                            sex = ifelse(is.na(Sex), 3, Sex), missid = 0))
dfull <- data.frame(personID = ped$Indiv,
                    momID    = ped$Dam,
                    dadID    = ped$Sire,
                    famID    = NA_character_,
                    sex      = ifelse(is.na(ped$Sex), NA_integer_, ped$Sex),
                    spouseID = NA_character_)
dtfull <- data.frame(id   = ped$Indiv,
                     dam  = ped$Dam,
                     sire = ped$Sire)
sxfull <- ifelse(!is.na(ped$Sex) & ped$Sex == 1, 1L, 0L)
pofull <- ped
pofull$Sex <- ifelse(is.na(pofull$Sex), "female", ifelse(pofull$Sex == 1, "male", "female"))
pdfull <- data.frame(id    = ped$Indiv,
                     dadid = ifelse(is.na(ped$Sire), 0, ped$Sire),
                     momid = ifelse(is.na(ped$Dam), 0, ped$Dam),
                     sex   = ifelse(is.na(ped$Sex), 0L, ped$Sex),
                     famid = rep("F1", nrow(ped)))
Pfull <- Pedigree(pdfull)
remap <- data.frame(id   = as.integer(seq_len(nrow(ped))),
                    dam  = as.integer(match(ped$Dam, ped$Indiv, nomatch = 0)),
                    sire = as.integer(match(ped$Sire, ped$Indiv, nomatch = 0)))

## ---- timed calls ----------------------------------------------------------
time_one <- function(tp, k, d, dt, sx, po, P, ped_cex, trunc = TRUE) {
  kid <- if (trunc) short_id(k$id) else k$id
  pdd <- if (trunc) d else NULL
  c(
    pedtricks    = med(function() { pdf(NULL); draw_ped(dt, sex = sx, cex = 0.9); dev.off() }),
    optiSel      = med(function() { pdf(NULL); pedplot(po); dev.off() }),
    kinship2     = med(function() { pdf(NULL); plot(k, id = kid, cex = 0.9); dev.off() }),
    Pedixplorer  = med(function() { g <- plot(P, cex = ped_cex); pdf(NULL); print(g); dev.off() }),
    visPedigree  = med(function() {
      pdf(NULL)
      if (trunc) visped(tp, labelvar = "ID4", showgraph = TRUE, cex = 0.9)
      else       visped(tp, showgraph = TRUE)
      dev.off()
    }),
    ggpedigree   = med(function() { g <- ggPedigree(d, interactive = FALSE); pdf(NULL); print(g); dev.off() })
  )
}

message("Timing the 30-animal pedigree ...")
small <- time_one(tp30, k30, d30, dt30, sx30, po30, P30, ped_cex = 1, trunc = TRUE)
print(round(small, 4))

if (DO_FULL) {
  message("Timing the 1,179-animal pedigree (this takes ~20 minutes) ...")
  big <- time_one(tpfull, kfull, dfull, dtfull, sxfull, pofull, Pfull,
                  ped_cex = 0.25, trunc = FALSE)
  print(round(big, 4))
  message("Timing purgeR ped_graph() on the remapped 1,179-animal pedigree ...")
  print(round(med(function() ped_graph(remap)), 4))
}

message("Done.\n")
