#!/usr/bin/env Rscript
#
# @package MiGA
# @license Artistic-2.0
#

#= Load stuff
argv <- commandArgs(trailingOnly=T)
suppressPackageStartupMessages(library(ape))

find_medoids <- function(dist, out, clades) {
  dist <- as.matrix(dist)
  cl <- read.table(clades, header = FALSE, sep = '\t', as.is = TRUE)[,1]
  medoids <- c()
  for(i in cl){
    lab <- strsplit(i, ',')[[1]]
    cat('Clade of:', lab[1], '\n')
    if(length(lab) == 1) {
      med <- lab
    } else {
      med <- lab[which.min(colSums(dist[lab, lab], na.rm = TRUE))]
    }
    medoids <- c(medoids, med)
  }
  write.table(medoids, out, quote = FALSE, row.names = FALSE, col.names = FALSE)
}

#= Main
load(argv[1])
find_medoids(dist = ani.d, out = argv[2], clades = argv[3])

