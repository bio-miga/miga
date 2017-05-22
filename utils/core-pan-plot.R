#!/usr/bin/env Rscript

argv <- commandArgs(trailingOnly=T)

plot_core_pan <- function(core_pan, pdf){
  a <- read.table(core_pan, sep="\t", header=TRUE)
  pdf(pdf, 7, 5)
  plot(1, type="n", xlim=c(0, max(a$genomes)*1.05), xaxs="i", yaxs="i",
    ylim=c(0, max(a$pan_q3)*1.05), xlab="Genomes", ylab="Orthologous Groups")
  # Core
  polygon(c(a$genomes, rev(a$genomes)), c(a$core_q1, rev(a$core_q3)),
    border=NA, col=rgb(0, 121, 166, 128/2, max=255))
  lines(a$genomes, a$core_avg, col=rgb(0,121,166,max=255), lty=2)
  lines(a$genomes, a$core_q2, col=rgb(0,121,166,max=255), lty=1)
  # Pan
  polygon(c(a$genomes, rev(a$genomes)), c(a$pan_q1, rev(a$pan_q3)),
    border=NA, col=rgb(96, 11, 64, 128/2, max=255))
  lines(a$genomes, a$pan_avg, col=rgb(96,11,64,max=255), lty=2)
  lines(a$genomes, a$pan_q2, col=rgb(96,11,64,max=255), lty=1)
  # Legend
  legend("topleft",
    legend=c("pangenome","core genome","Inter-Quartile","Median","Average"),
    pch=c(16,16,15,NA,NA),lty=c(NA,NA,NA,1,2), pt.cex=c(1,1,2,NA,NA),
    col=c(rgb(96,11,64,max=255), rgb(0,121,166,max=255),
      rgb(0.5,0.5,0.5,166/255), rep(rgb(0.5,0.5,0.5),2)), bty="n")
  dev.off()
}

plot_core_pan(argv[1], argv[2])
