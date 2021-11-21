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

find_medoids <- function (ani.df, out, clades) {
  if(nrow(ani.df) == 0) return(NULL)
  ani.df$d <- 1 - (ani.df$value/100)
  dist <- enve.df2dist(ani.df, "a", "b", "d", default.d = max(ani.df$d) * 1.2)
  dist <- as.matrix(dist)
  cl <- read.table(clades, header = FALSE, sep = "\t", as.is = TRUE)[,1]
  cl.s <- c()
  medoids <- c()
  for(i in cl){
    lab <- strsplit(i, ",")[[1]]
    cat("Clade of:", lab[1], "\n")
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
cat("Finding Medoids")
ani <- readRDS(argv[1])
find_medoids(ani.df = ani, out = argv[2], clades = argv[3])

