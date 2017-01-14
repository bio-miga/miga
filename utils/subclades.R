#!/usr/bin/env Rscript
#
# @package MiGA
# @license Artistic-2.0
#

#= Load stuff
argv <- commandArgs(trailingOnly=T)
suppressPackageStartupMessages(library(ape))
suppressPackageStartupMessages(library(vegan))
suppressPackageStartupMessages(library(cluster))
suppressPackageStartupMessages(library(parallel))
suppressPackageStartupMessages(library(enveomics.R))

#= Main function
subclades <- function(ani_file, out_base, thr=1, ani=c()) {
  say("==> Out base:", out_base, "<==")
  
  # Input arguments
  if(missing(ani_file)){
    a <- as.data.frame(ani)
  }else{
    a <- read.table(gzfile(ani_file), sep="\t", header=TRUE, as.is=TRUE)
  }
  if(nrow(a)==0){
    generate_empty_files(out_base)
    return(NULL)
  }
  
  # Get ANI distances
  say("Distances")
  a$d <- 1-a$value/100
  ani.d <- enve.df2dist(data.frame(a$a, a$b, a$d), default.d=max(a$d)*1.2)
  ani.ph <- bionj(ani.d)
  write.tree(ani.ph, paste(out_base, ".nwk", sep=""))
  
  # Silhouette
  say("Silhouette")
  k <- 2:min(length(labels(ani.d))-1, 100)
  cl <- makeCluster(thr)
  s <- parSapply(cl, k, function(x) {
      library(cluster)
      s <- pam(ani.d, x, do.swap=FALSE, pamonce=1)$silinfo
      c(s$avg.width, -sum(ifelse(s$widths[,3]>0,0,s$widths[,3])))
    })
  stopCluster(cl)
  s.avg.z <- (s[1,]-mean(s[1,]))/sd(s[1,])
  s.neg.z <- (s[2,]-mean(s[2,]))/sd(s[2,])
  ds <- s.avg.z - s.neg.z - 2/(1:length(k)) - (1:length(k))/50
  top.n <- k[which.max(ds)]
  
  # Classify genomes
  say("Classify => k :", top.n, "| n :", length(labels(ani.d)))
  ani.cl <- pam(ani.d, top.n, pamonce=1)
  ani.types <- ani.cl$clustering
  ani.medoids <- ani.cl$medoids
  
  # Generate graphic report
  say("Graphic report")
  pdf(paste(out_base, ".pdf", sep=""), 7, 12)
  layout(1:4)
  plot_distances(ani.d)
  plot_silhouette(k, s[1,], s[2,], ds, top.n)
  plot_clustering(ani.cl, ani.d, ani.types)
  plot_tree(ani.ph, ani.types, ani.medoids)
  dev.off()

  # Save results
  say("Text report")
  write.table(ani.medoids, paste(out_base, "medoids", sep="."),
    quote=FALSE, col.names=FALSE, row.names=FALSE)
  save(ani.d, file=paste(out_base, "dist.rdata", sep="."))
  classif <- cbind(names(ani.types), ani.types, ani.medoids[ ani.types ], NA)
  for(j in 1:nrow(classif)){
    classif[j,4] <- 100 - as.matrix(ani.d)[classif[j,1], classif[j,3]]
  }
  write.table(classif, paste(out_base,"classif",sep="."),
    quote=FALSE, col.names=FALSE, row.names=FALSE, sep="\t")

  # Recursive search
  say("Recursive search")
  for(i in 1:top.n){
    medoid <- ani.medoids[i]
    ds_f <- names(ani.types)[ ani.types==i ]
    say("Analyzing subclade", i, "with medoid:", medoid)
    dir.create(paste(out_base, ".sc-", i, sep=""))
    write.table(ds_f,
      paste(out_base, ".sc-", i, "/miga-project.all",sep=""),
      quote=FALSE, col.names=FALSE, row.names=FALSE)
    if(length(ds_f) > 5){
      a_f <- a[ (a$a %in% ds_f) & (a$b %in% ds_f), ]
      subclades(out_base=paste(out_base, ".sc-", i, "/miga-project", sep=""),
        thr=thr, ani=a_f)
    }
  }
}

#= Helper functions
say <- function(...) { cat("[", date(), "]", ..., "\n") }

generate_empty_files <- function(out_base) {
  pdf(paste(out_base, ".pdf", sep=""), 7, 12)
  plot(1, t="n", axes=F)
  legend("center", "No data", bty="n")
  dev.off()
  file.create(paste(out_base,".1.classif",sep=""))
  file.create(paste(out_base,".1.medoids",sep=""))
}

plot_silhouette <- function(k, s, ns, ds, top.n) {
  # s
  par(mar=c(4,5,1,5)+0.1)
  plot(1, t="n", xlab="k (clusters)", ylab="", xlim=range(c(0,k)),
    ylim=range(s), bty="n", xaxs="i", yaxt="n")
  polygon(c(k[1], k, k[length(k)]), c(0,s,0), border=NA, col="grey80")
  axis(2, fg="grey60", col.axis="grey60")
  mtext("Mean silhouette", side=2, line=3, col="grey60")
  # ns
  par(new=TRUE)
  plot(1, t="n", xlab="", xaxt="n", ylab="", yaxt="n", xlim=range(c(0,k)),
    ylim=range(ns), bty="n", xaxs="i")
  points(k, ns, type="o", pch=16, col=rgb(1/2,0,0,3/4))
  axis(4, fg="darkred", col.axis="darkred")
  mtext("Negative silhouette area", side=4, line=3, col="darkred")
  # ds
  par(new=TRUE)
  plot(1, t="n", xlab="", xaxt="n", ylab="", yaxt="n", xlim=range(c(0,k)),
    ylim=range(ds), bty="n", xaxs="i")
  lines(k, ds)
  abline(v=top.n, lty=2)
}

plot_distances <- function(dist) {
  par(mar=c(5,4,1,2)+0.1)
  hist(dist, border=NA, col="grey60", breaks=50, xlab="Distances", main="")
}

plot_clustering <- function(cl, dist, types) {
  par(mar=c(5,4,4,2)+0.1)
  top.n <- length(cl$medoids)
  col <- ggplotColours(top.n)
  plot(silhouette(cl), col=col)
  if(length(labels(dist))<=15){
    plot(1, type="n", axes=FALSE, xlab="", ylab="", bty="n")
  }else{
    clusplot(cl, dist=dist, main="", col.p=col[types], lines=0)
  }
}

plot_tree <- function(phy, types, medoids){
  layout(1)
  top.n <- length(unique(types))
  col <- ggplotColours(top.n)
  is.medoid <- phy$tip.label %in% medoids
  plot(phy, cex=ifelse(is.medoid, 1/3, 1/6),
    font=ifelse(is.medoid, 2, 1),
    tip.color=col[types[phy$tip.label]])
}

ggplotColours <- function(n=6, h=c(0, 360)+15, alpha=1){
  if ((diff(h)%%360) < 1) h[2] <- h[2] - 360/n
  hcl(h=seq(h[1], h[2], length=n), c=100, l=65, alpha=alpha)
}

#= Main
subclades(ani_file=argv[1], out_base=argv[2],
  thr=ifelse(is.na(argv[3]), 1, as.numeric(argv[3])))

