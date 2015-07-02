
mytaxa.scan <- function(wintax, col=c('#4dbeee', '#7e2f8e', '#0072bd', '#d95319', '#edb120', '#77ac30', '#a2142f'), main='MyTaxa scan'){
   a <- read.table(wintax, sep='\t', h=F, row.names=1, na.strings='');
   if(! "NA" %in% rownames(a)) a["NA", ] <- 0
   b <- as.matrix(a[-which(rownames(a)=="NA"),-1]);

   layout(matrix(c(6,6,1,4,2,3,5,5),byrow=T,ncol=2), widths=c(7,1), heights=c(1/4,1,2,3));
   
   #::: DISTANCES
   par(mar=c(1,5,2,0)+0.1);
   d <- apply( a[,-1], 2, function(x,y) sqrt(sum((sqrt(x)-sqrt(y))^2)/2), y=a[,1] );
   d.thr <- quantile(d, probs=0.95, names=F)
   plot(1, xlim=c(0, length(d)+1), ylim=c(0,1), xlab='', xaxs='i', xaxt='n', t='n', pch=19, cex=1/2, col=grey(0.3), bty='n', ylab='Signal', las=1);
   rect((1:length(d))-1, 0, 1:length(d), d, col=ifelse(d>d.thr, grey(0.3), grey(0.5)), border='NA');

   #::: WINDOWS BARPLOT
   par(mar=c(0,5,0,0)+0.1);
   plot(1, t='n', xlim=c(0,ncol(b)+1), xaxs='i', ylim=c(0,1.2), yaxs='i', xlab='', ylab='Frequency', bty='n', xaxt='n', yaxt='n');
   axis(2, at=seq(0,1,by=0.2), las=1);
   # Regions (outliers)
   regs <- c();
   for(j in 1:ncol(b))  if(d[j] > d.thr) regs <- c(regs, j);
   if(length(regs)>0){
      x <- regs-0.5;
      y <- rep(1.05,length(regs)) + ((1:length(regs)) %% 2)/10;
      points(x, y, pch=19, cex=3, col='darkred');
      arrows(x0=x, y0=0.01, y1=y, col='darkred', length=0);
      text(x, y, 1:length(regs), col='white', font=2, cex=3/4);
      write.table(regs, paste(wintax,".regions",sep=""), col.names=F, row.names=F, quote=F)
   }
   # Bars
   h <- rep(0, ncol(b));
   all_cols <- c();
   for(i in 1:nrow(b)){
      i.col = 1+((i-1) %% (length(col)-1));
      hn <- h + as.numeric(b[i, ]);
      for(j in 1:ncol(b)) if(b[i,j]>0) rect(j-1, h[j], j, hn[j], col=col[i.col], border=NA);
      all_cols <- c(all_cols, col[i.col]);
      if(i.col+1 == length(col))
	 for(j in 1:length(col)){
	    k = col2rgb(col[j]);
	    col[j] = rgb(k[1], k[2], k[3], maxColorValue=256*1.3)
	 }
      h <- hn;
   }

   #::: GENOME PROFILE
   par(mar=c(0,0,0,2)+0.1);
   plot(1, t='n', xlim=c(0,1), xaxs='i', ylim=c(0,1.2), yaxs='i', xlab='', ylab='', bty='n', xaxt='n', yaxt='n');
   rect(0, cumsum(c(0,a[-nrow(a),1])), 1, cumsum(a[, 1]), col=all_cols, border=NA);
   text(0.5, 1.1, 'Genome', font=2, cex=1.5, col='darkred');

   #::: DISTANCES BOXPLOT
   par(mar=c(1,0,2,2)+0.1);
   boxplot(d, ylim=c(0,1), yaxs='i', axes=F, col=grey(0.3), pch=19);
   
   #::: LEGEND
   par(mar=c(0,2,0,2)+0.1);
   plot(1, t='n', bty='n', xlim=c(0,1), ylim=c(0,1), xaxs='i', yaxs='i', axes=F);
   legend('top', pt.bg=all_cols, col=grey(0.3), pch=22, legend=gsub('.*::','',rownames(b)), ncol=5, cex=3/4, bty='n');

   #::: MAIN
   plot(1, t='n', bty='n', xlim=c(0,1), ylim=c(0,1), axes=F);
   text(.5,.5,main);
   
   return(regs);
}

