#!/usr/bin/env Rscript

# @package MiGA
# @license Artistic-2.0

##
# To update the AAI data files, use:
# 
# ```bash
# miga tax_distributions -P /Path/To/RefSeq --ref | cut -f 1-5 \
#   > aai-tax-index.tsv
# ```
# 
# Next, in R:
# 
# ```R
# source("utils/plot-taxdist.R")
# p.val <- plot.miga.taxdist("aai-tax-index.tsv",
#   exclude=c("g:Mycoplasma", "ssp:Prochlorococcus_marinus_subsp__marinus",
#   "f:Rhizobiaceae", "s:Buchnera_aphidicola", "s:Prochlorococcus_marinus"))
# write.table(p.val[[1]], file="lib/miga/_data/aai-intax.tsv",
#   sep="\t", row.names=TRUE, col.names=NA, quote=FALSE)
# write.table(p.val[[2]], file="lib/miga/_data/aai-novel.tsv",
#   sep="\t", row.names=TRUE, col.names=NA, quote=FALSE)
# ```
#
# And finally, back in bash:
# 
# ```bash
# gzip lib/miga/_data/aai-intax.tsv
# gzip lib/miga/_data/aai-novel.tsv
# rm aai-tax-index.tsv
# ```
#

#= Load stuff
#argv <- commandArgs(trailingOnly=T)

#= Functions
plot.miga.taxdist <- function(file, exclude=c()){
  pdf(paste(file, ".pdf", sep=""), 6, 7)
  layout(1:3, heights=c(2,1,1.5))
  d <- read.table(file, sep="\t", header=FALSE,
    col.names=c("a","b","aai","rank","taxon"), as.is=TRUE)
  a <- d[!(d$taxon %in% exclude),]
  col <- rainbow(max(a$rank)+1, s=3/4, v=3/4, alpha=1/3)
  col2 <- rainbow(max(a$rank)+1, s=3/4, v=3/4)

  cat("o Plot pairs.\n")
  par(mar=c(0,4,1,1)+0.1)
  plot(d$aai, d$rank+runif(nrow(d), -0.3, 0.3), cex=1/2, pch=16, las=1, bty="l",
    col=ifelse(d$taxon %in% exclude, rgb(.8,.8,.8,1/4), col[d$rank+1]),
    xlab="", ylab="Lowest common taxon", xaxt="n", ylim=rev(range(a$rank)))
  for(i in c(0.1, 0.05, 0.01)){
    min_q <- tapply(a$aai, a$rank, quantile, probs=i)
    max_q <- tapply(a$aai, a$rank, quantile, probs=1-i)
    arrows(x0=min_q, length=0, col=grey(1+log10(i)/2),
      y0=as.numeric(names(min_q))-0.45, y1=as.numeric(names(min_q))+0.45)
    arrows(x0=max_q, length=0, col=grey(1+log10(i)/2),
      y0=as.numeric(names(max_q))-0.45, y1=as.numeric(names(max_q))+0.45)
  }
  
  cat("o Plot taxa.\n")
  par(mar=c(0,4,0,1)+0.1)
  plot(1, type="n", xlim=range(a$aai), ylim=rev(range(a$rank)),
    xlab="", ylab="Lowest common taxon", xaxt="n", las=1, bty="l")
  for(i in unique(a$rank)){
    t.aai <- tapply(d$aai[d$rank==i], d$taxon[d$rank==i], mean)
    t.size <- tapply(d$aai[d$rank==i], d$taxon[d$rank==i], length)
    points(t.aai, i+runif(length(t.aai), -0.15, 0.15), pch=16,
      cex=2*log2(1+t.size)/log2(1+max(t.size)),
      col=ifelse(names(t.aai) %in% exclude, rgb(.8,.8,.8,1/4), col[i+1]))
  }
  
  cat("o Plot p-values.\n")
  par(mar=c(4,4,0,1)+0.1)
  plot(1, type="n", xlim=range(a$aai), ylim=c(0,0.5),
    xlab="AAI (%)", ylab="P-value (--- intax; - - novel)", las=1, bty="l")
  x <- seq(30, 100, 0.1)
  intax <- data.frame(row.names=x)
  novel <- data.frame(row.names=x)
  for(i in sort(unique(a$rank))){
    if(i==12) next
    k <- as.character(i)
    intax[,k] <- miga.taxprob.intax(x, i, a)
    novel[,k] <- miga.taxprob.novel(x, i, a)
    lines(x, intax[,k], col=col2[i+1], lwd=2)
    lines(x, novel[,k], col=col2[i+1], lwd=2, lty=2)
  }
  dev.off()
  return(list(intax, novel))
}

miga.taxprob.novel <- function(max.aai, rank, data){
  o <- c()
  for(i in max.aai){
    a <- sum(data$rank >= rank & data$aai <= i)/sum(data$aai <= i)
    o <- c(o, a)
  }
  return(o*sum(data$rank < 12)/sum(data$rank >= rank))
}

miga.taxprob.intax <- function(max.aai, rank, data){
  o <- c()
  for(i in max.aai){
    a <- sum(data$rank < rank & data$aai >= i)/sum(data$aai >= i)
    o <- c(o, a)
  }
  return(o*sum(data$rank < 12)/sum(data$rank < rank))
}
