library(enveomics.R)
library(ape)
library(ggdendro)
library(ggplot2)
library(grid)
library(gridExtra)
library(cluster)
library(dendextend)
library(vegan)
library(scatterplot3d)

# Main function
subclades <- function(ani_file, out_base, thr=1, ani=c()){
   # Get ANI distances
   cat("====", out_base, "\n")
   if(missing(ani_file)){
      a <- as.data.frame(ani)
   } else {
      a <- read.table(gzfile(ani_file), sep='\t', h=TRUE, as.is=T)
   }
   if(nrow(a)==0){
      pdf(paste(out_base,'.pdf',sep=''), 7, 12)
      plot(1,t='n',axes=F)
      legend('center','No ANI data',bty='n')
      dev.off()
      file.create(paste(out_base,'.1.classif',sep=''))
      file.create(paste(out_base,'.1.medoids',sep=''))
      return(NULL)
   }
   ani.d <- enve.df2dist(cbind(a$a, a$b, 100-a$value), default.d=30)
   ani.hc <- hclust(ani.d, method='ward.D2')
   
   # Silhouette
   k <- 2:(length(labels(ani.d))-1)
   s <- sapply(k, function(x) summary(silhouette(pam(ani.d, x)))$avg.width)
   ds <- 10^(s[-c(1,length(s))]-(s[-length(s)+c(0,1)]+s[-c(1,2)])/2)
   top.n <- head(k[order(c(-Inf,ds,-Inf), decreasing=T)],n=6)

   # Save "ANI-types"
   ani.types <- c()
   ani.medoids <- list()
   for(i in 1:length(top.n)){
      k_i <- top.n[i]
      ani.cl <- pam(ani.d, k_i)
      ani.types <- cbind(ani.types, ani.cl$clustering)
      ani.medoids[[ i ]]  <- ani.cl$medoids
   }

   # Generate graphic reports
   pdf(paste(out_base,'.pdf',sep=''), 7, 12)
   plotClusterAndMetadata(as.dendrogram(ani.hc), ani.types, main='ANI types')
   ani.mds <- metaMDS(ani.d, k=3, autotransform=FALSE, parallel=thr, wascores=F)
   layout(matrix(1:6, ncol=2))
   for(i in 1:length(top.n)){
      s <- scatterplot3d(ani.mds$points, pch=19, type='h',
	 color=ggplotColours(top.n[i], alpha=1/2)[ani.types[,i]],
	 cex.symbols=1/2, box=FALSE, lty.hplot=3,
	 main=paste('NMDS of ANI distances with', top.n[i] ,'clusters'),
	 angle=80, scale.y=3/2, las=2, xlab='', ylab='', zlab='')
      for(cl in 1:top.n[i]){
	 col <- ggplotColours(top.n[i])[cl]
	 med <- s$xyz.convert(matrix(ani.mds$points[ ani.medoids[[i]][cl] , ],
	    ncol=3))
	 if(sum(ani.types[,i]==cl)>1){
	    val <- s$xyz.convert(matrix(ani.mds$points[ ani.types[,i]==cl , ],
	       ncol=3))
	    arrows(x0=med$x, y0=med$y, x1=val$x, y1=val$y, length=0, col=col)
	 }
	 points(med, col=col, pch=19, cex=3/2)
	 text(med, labels=cl, col='white', cex=2/3)
      }
   }
   dev.off()

   # Save results
   for(i in 1:length(top.n)){
      write.table(ani.medoids[[i]], paste(out_base,i,'medoids',sep='.'),
	 quote=FALSE, col.names=FALSE, row.names=FALSE)
      classif <- cbind(rownames(ani.types), ani.types[,i],
	 ani.medoids[[i]][ ani.types[,i] ], NA)
      for(j in 1:nrow(classif))
	 classif[j,4] <- 100 - as.matrix(ani.d)[classif[j,1], classif[j,3]]
      write.table(classif, paste(out_base,i,'classif',sep='.'),
	 quote=FALSE, col.names=FALSE, row.names=FALSE, sep='\t')
   }

   # Explore subclades
   for(i in 1:top.n[1]){
      medoid <- ani.medoids[[1]][i]
      ds_f <- labels(as.dendrogram(ani.hc))[ ani.types[,1]==i ]
      cat("Analyzing subclade", i, "with medoid:", medoid, "\n")
      cat("   ds_f: ", ds_f, "\n")
      if(length(ds_f) > 5){
	 a_f <- a[ a$a %in% ds_f & a$b %in% ds_f, ]
	 dir.create(paste(out_base,'.1.sc-',i,sep=''))
	 write.table(ds_f,
	    paste(out_base,'.1.sc-',i,'/miga-project.all',sep=''),
	    quote=FALSE, col.names=FALSE, row.names=FALSE)
	 cat("   looking for subclades within: ",
	    out_base, ".1.sc-", i, "\n", sep="")
	 subclades(
	    out_base=paste(out_base,'.1.sc-',i,'/miga-project',sep=''),
	    thr=thr, ani=a_f)
      }
   }
}

# Ancillary functions
plotClusterAndMetadata <- function(c,m,addLabels=TRUE,main='',type='factor'){
   ps <- list()
   ps[[1]] <- rectGrob(gp=gpar(col="white"))
   if(length(type)==1) type <- rep(type, ncol(m))
   if(addLabels){
      m <- cbind(m, NA)
      m[labels(c),ncol(m)] <- labels(c)
      type[ncol(m)] <- 'label'
   }
   for(i in 1:ncol(m)){
      df <- data.frame(lab=factor(labels(c),levels=labels(c)),
	 feat=m[labels(c),i])
      if(type[i]=='factor'){
	 ps[[i+1]] <- ggplotGrob(ggplot(df,  aes(1, lab, fill=factor(feat))) +
	    geom_tile() + geom_text(size=3/4, label=df$feat, x=.8) +
	    scale_x_continuous(expand=c(0,0)) +
	    theme(axis.title=element_blank(), panel.margin=unit(1,'points'),
	       plot.margin=unit(c(40,-12,20,-12),'points'),
	       axis.ticks=element_blank(), axis.text=element_blank(),
	       legend.position="none"))
      }else if(type[i]=='numeric'){
	 ps[[i+1]] <- ggplotGrob(ggplot(df, aes(1,lab,fill=as.numeric(feat))) +
	    geom_tile() + geom_text(size=3/4, label=df$feat, x=.8) +
	    scale_x_continuous(expand=c(0,0)) +
	    theme(axis.title=element_blank(), panel.margin=unit(1,'points'),
	       plot.margin=unit(c(40,-12,20,-12),'points'),
	       axis.ticks=element_blank(), axis.text=element_blank(),
	       legend.position="none"))
      }else if(type[i]=='label'){
	 ps[[i+1]] <- ggplotGrob(ggplot(df,  aes(1, lab)) +
	    geom_tile(fill='white') + geom_text(size=3/4, label=df$feat, x=.8) +
	    theme(axis.title=element_blank(), panel.margin=unit(1,'points'),
	       plot.margin=unit(c(40,-12,20,-12),'points'),
	       axis.ticks=element_blank(), axis.text=element_blank(),
	       legend.position="none"))
      }else{
	 stop('Unsupported type: ', type[i])
      }
   }
   ps[[i+2]] <- ggplotGrob(ggplot(segment(dendro_data(c, type="rectangle"))) +
      geom_segment(aes(x = x, y = y, xend = xend, yend = yend)) +
      scale_x_continuous(expand=c(0,.5)) +
      coord_flip() + theme_dendro() +
         theme(axis.title=element_blank(), axis.ticks=element_blank(),
	    plot.margin=unit(c(40,20,20,ifelse(addLabels,-35,-30)),'points'),
            panel.margin=unit(0,'points'), axis.text=element_blank(),
	    legend.position="none"))
   maxHeights = do.call(grid::unit.pmax, lapply(ps, function(x) x$heights[2:5]))
   for(g in ps) g$heights[2:5] <- as.list(maxHeights)
   ps$nrow <- 1
   ps$widths <- c(0.1,rep(.07,ncol(m)),1)
   ps$main <- main
   do.call(grid.arrange, ps)
   return(ps)
}

ggplotColours <- function(n=6, h=c(0, 360)+15, alpha=1){
   if ((diff(h)%%360) < 1) h[2] <- h[2] - 360/n
   hcl(h=seq(h[1], h[2], length=n), c=100, l=65, alpha=alpha)
}


