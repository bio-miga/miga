#!/usr/bin/env Rscript
#
# @package MiGA
# @license Artistic-2.0
#

#= Load stuff
argv <- commandArgs(trailingOnly = T)
suppressPackageStartupMessages(library(ape))
suppressPackageStartupMessages(library(enveomics.R))

find_medoids <- function(ani.df, out, clades) {
  if(nrow(ani.df) == 0) return(NULL)
  ani.df$d <- 1 - (ani.df$value/100)
  dist <- enve.df2dist(ani.df, 'a', 'b', 'd', default.d = max(ani.df$d)*1.2)
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
if(! exists('ani')) ani <- aai
find_medoids(ani.df = ani, out = argv[2], clades = argv[3])

