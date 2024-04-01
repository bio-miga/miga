#!/usr/bin/env Rscript
#
# @package MiGA
# @license Artistic-2.0
#

#= Load stuff
argv <- commandArgs(trailingOnly = TRUE)
suppressPackageStartupMessages(library(ape))
if(Sys.getenv("MIGA") == ""){
  suppressPackageStartupMessages(library(enveomics.R))
}else{
  source(file.path(
    Sys.getenv("MIGA"),
    "utils", "enveomics", "enveomics.R", "R", "df2dist.R"
  ))
}

find_medoids <- function (a, b, d, out, clades) {
  if (length(d) == 0) return(NULL)
  dist <- enve.df2dist(cbind(a, b, d), "a", "b", "d", default.d = max(d) * 1.2)
  dist <- as.matrix(dist)
  cl <- read.table(clades, header = FALSE, sep = "\t", as.is = TRUE)[,1]
  cl.s <- c()
  medoids <- c()
  for (i in cl) {
    lab <- strsplit(i, ",")[[1]]
    if(length(lab) == 1) {
      lab.s <- lab
    } else {
      lab.s <- lab[order(colSums(dist[lab, lab], na.rm = TRUE))]
    }
    med <- lab.s[1]
    medoids <- c(medoids, med)
    cl.s <- c(cl.s, paste(lab.s, collapse = ","))
  }
  write.table(medoids, out, quote = FALSE, row.names = FALSE, col.names = FALSE)
  write.table(
    cl.s, paste(clades, ".sorted", sep = ""), quote = FALSE,
    row.names = FALSE, col.names = FALSE
  )
}

#= Main
cat("Finding Medoids\n")
if (grepl("\\.rds$", argv[1])) {
  ani <- readRDS(argv[1])
  find_medoids(ani$a, ani$b, 1 - (ani$value / 100),
    out = argv[2], clades = argv[3])
} else {
  load(argv[1]) # assume .rda
  find_medoids(a, b, d, out = argv[2], clades = argv[3])
}

