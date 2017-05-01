#!/usr/bin/env Rscript
#
# @package MiGA
# @license Artistic-2.0
#

#= Load stuff
argv <- commandArgs(trailingOnly=T)
suppressPackageStartupMessages(library(ape))
suppressPackageStartupMessages(library(phytools))
suppressPackageStartupMessages(library(phangorn))
suppressPackageStartupMessages(library(enveomics.R))

#= Main function
ref_tree <- function(ani_file, out_base, q_dataset) {
  a <- read.table(ani_file, sep="\t", header=TRUE, as.is=TRUE)
  ani.d <- enve.df2dist(a[,1:3], default.d=0.9, max.sim=100)
  ani.ph <- midpoint(bionj(ani.d))
  write.tree(ani.ph, paste(out_base, ".nwk", sep=""))
  pdf(paste(out_base, ".nwk.pdf", sep=""), 7, 7)
  plot(ani.ph, cex=1/3, type='fan',
    tip.color=c('red', 'black')[ifelse(ani.ph$tip.label==q_dataset, 1, 2)])
  add.scale.bar()
  dev.off()
}

# Ancilliary functions
midpoint <- function(tree){
  dm = cophenetic(tree)
  tree = unroot(tree)
  rn = max(tree$edge)+1
  maxdm = max(dm)
  ind = which(dm==maxdm,arr=TRUE)[1,]
  tmproot = Ancestors(tree, ind[1], "parent")
  tree = phangorn:::reroot(tree, tmproot)
  edge = tree$edge
  el = tree$edge.length
  children = tree$edge[,2]
  left = match(ind[1], children)
  tmp = Ancestors(tree, ind[2], "all")
  tmp= c(ind[2], tmp[-length(tmp)])
  right = match(tmp, children)
  if(el[left]>= (maxdm/2)){
    edge = rbind(edge, c(rn, ind[1]))
    edge[left,2] = rn
    el[left] = el[left] - (maxdm/2)
    el = c(el, maxdm/2)
  }else{
    sel = cumsum(el[right])
    i = which(sel>(maxdm/2))[1]
    edge = rbind(edge, c(rn, tmp[i]))
    edge[right[i],2] = rn
    eltmp = sel[i] - (maxdm/2)
    el = c(el, el[right[i]] - eltmp)
    el[right[i]] = eltmp
  }
  tree$edge.length = el
  tree$edge=edge
  tree$Nnode = tree$Nnode+1
  phangorn:::reorderPruning(phangorn:::reroot(tree, rn))
}

#= Main
ref_tree(ani_file=argv[1], out_base=argv[2], q_dataset=argv[3])

