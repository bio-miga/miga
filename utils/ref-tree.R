#!/usr/bin/env Rscript
#
# @package MiGA
# @license Artistic-2.0
#

#= Load stuff
argv <- commandArgs(trailingOnly=T)
suppressPackageStartupMessages(library(ape))
if(Sys.getenv('MIGA') == ''){
  suppressPackageStartupMessages(library(enveomics.R))
}else{
  source(file.path(Sys.getenv('MIGA'),
    'utils', 'enveomics', 'enveomics.R', 'R', 'df2dist.R'))
}
inst <- c("phangorn", "phytools") %in% rownames(installed.packages())
if(inst[1]){
  suppressPackageStartupMessages(library(phangorn))
  reroot.fun <- midpoint
}else if(inst[2]){
  suppressPackageStartupMessages(library(phytools))
  reroot.fun <- midpoint.root
}else{
  reroot.fun <- function(x) return(x)
}

#= Main function
ref_tree <- function(ani_file, out_base, q_dataset) {
  a <- read.table(ani_file, sep="\t", header=TRUE, as.is=TRUE)
  ani.d <- enve.df2dist(a[,1:3], default.d=0.9, max.sim=100)
  ani.ph <- reroot.fun(bionj(ani.d))
  write.tree(ani.ph, paste(out_base, ".nwk", sep=""))
  pdf(paste(out_base, ".nwk.pdf", sep=""), 7, 7)
  plot(ani.ph, cex=1/3, type='fan',
    tip.color=c('red', 'black')[ifelse(ani.ph$tip.label==q_dataset, 1, 2)])
  add.scale.bar()
  dev.off()
}

#= Main
ref_tree(ani_file=argv[1], out_base=argv[2], q_dataset=argv[3])

