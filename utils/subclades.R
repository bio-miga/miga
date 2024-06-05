#!/usr/bin/env Rscript
#
# @package MiGA
# @license Artistic-2.0
#

#= Load stuff
argv <- commandArgs(trailingOnly = TRUE)
suppressPackageStartupMessages(library(ape))
suppressPackageStartupMessages(library(vegan))
suppressPackageStartupMessages(library(cluster))
suppressPackageStartupMessages(library(parallel))
if(Sys.getenv("MIGA") == ""){
  suppressPackageStartupMessages(library(enveomics.R))
}else{
  source(file.path(
    Sys.getenv("MIGA"),
    "utils", "enveomics", "enveomics.R", "R", "df2dist.R"
  ))
}

#= Main function
subclades <- function(ani_file, out_base, thr = 1, ani.d = dist(0), sel = NA) {
  say("==> Out base:", out_base, "<==")

  # Normalize input matrix
  dist_rds <- paste(out_base, "dist.rds", sep = ".")
  if (!missing(ani_file)) {
    if (length(ani.d) == 0) {
      if (file.exists(dist_rds)) {
        ani.d <- readRDS(dist_rds)
      } else {
        # Read from ani_file
        ani.d <- ani_distance(ani_file, sel)
        if (is.null(ani.d)) {
          generate_empty_files(out_base)
          return(NULL)
        } else {
          saveRDS(ani.d, dist_rds)
        }
      }
    }
  }

  # Read result if the subclade is ready, run it otherwise
  if (file.exists(paste(out_base, "classif", sep = "."))) {
    say("Loading")
    ani.medoids <- read.table(paste(out_base, "medoids", sep = "."),
      sep = " ", as.is = TRUE)[,1]
    a <- read.table(paste(out_base, "classif", sep = "."),
      sep = "\t", as.is = TRUE)
    ani.types <- a[,2]
    names(ani.types) <- a[,1]
    if(length(ani.d) == 0) ani.d <- readRDS(dist_rds)
  } else if (length(labels(ani.d)) > 8L) {
    res <- subclade_clustering(out_base, thr, ani.d, dist_rds)
    if (length(res) == 0) return(NULL)
    ani.medoids <- res[["ani.medoids"]]
    ani.types <- res[["ani.types"]]
    ani.d <- res[["ani.d"]]
  } else {
    ani.medoids <- labels(ani.d)[which.min(colSums(as.matrix(ani.d)))]
    ani.types <- rep(1, length(labels(ani.d)))
    names(ani.types) <- labels(ani.d)
    generate_empty_files(out_base)
    write_text_report(out_base, ani.d, ani.medoids, ani.types)
  }

  # Recursive search
  say("Recursive search")
  for (i in 1:length(ani.medoids)) {
    medoid <- ani.medoids[i]
    ds_f <- names(ani.types)[ani.types == i]
    say("Analyzing subclade", i, "with medoid:", medoid)
    dir_f <- paste(out_base, ".sc-", i, sep = "")
    if (!dir.exists(dir_f)) dir.create(dir_f)
    write.table(ds_f,
      paste(out_base, ".sc-", i, "/miga-project.all", sep = ""),
      quote = FALSE, col.names = FALSE, row.names = FALSE)
    if (length(ds_f) > 8L) {
      ani_subset <- as.dist(as.matrix(ani.d)[ds_f, ds_f])
      subclades(
        out_base = paste(out_base, ".sc-", i, "/miga-project", sep = ""),
        thr = thr,
        ani.d = ani_subset
      )
    }
  }
  
  # Declare recursion up-to-here complete
  write.table(
    date(), paste(out_base, "ready", sep = "."),
    quote = FALSE, row.names = FALSE, col.names = FALSE
  )
}

#= Heavy-lifter
subclade_clustering <- function (out_base, thr, ani.d, dist_rds) {
  # Get ANI distances
  if (length(ani.d) > 0L) {
    # Just use ani.d (and save in dist_rds)
    if (!file.exists(dist_rds)) saveRDS(ani.d, dist_rds)
  } else if (file.exists(dist_rds)) {
    # Read from dist_rds
    ani.d <- readRDS(dist_rds)
  } else {
    stop("Cannot find input matrix", out_base)
  }
  if (length(labels(ani.d)) <= 8L) return(list())

  # Subsample huge collections
  nMax <- 65536L
  nn <- length(labels(ani.d))
  is.huge <- nn > nMax
  if (is.huge) {
    say("Subsampling large collection")
    ids <- sample(labels(ani.d), nMax)
    ani.d.ori <- ani.d
    ani.d.m <- as.matrix(ani.d)
    ani.d <- as.dist(ani.d.m[ids, ids])
  }

  # Silhouette
  say("Silhouette")
  k <- min(max(floor(0.005 * nn), 2), 20):min(nn - 1, 100)
  say("- Make cluster")
  cl <- makeCluster(thr)
  say("- Launch parallel jobs")
  s <- parSapply(
    cl, k,
    function(x, ani.d) {
      library(cluster)
      s <- pam(ani.d, x, do.swap = FALSE, variant = "faster")$silinfo
      c(s$avg.width, -sum(ifelse(s$widths[, 3] > 0, 0, s$widths[, 3])))
    },
    ani.d = ani.d
  )
  say("- Stop cluster")
  stopCluster(cl)
  say("- Calculate custom criteria")
  s.avg.z <- (s[1,] - mean(s[1,])) / (sd(s[1,]) + 0.0001)
  s.neg.z <- (s[2,] - mean(s[2,])) / (sd(s[2,]) + 0.01)
  ds <- s.avg.z - s.neg.z - 2 / (1:length(k)) - (1:length(k)) / 50
  if(mean(s[1,] < 0) < 0.75)
    ds[s[1,] < 0] <- mean(ds) # <- k's with negative average
  top.n <- k[which.max(ds)]

  # Classify genomes
  say("Classify => k :", top.n, "| n :", length(labels(ani.d)))
  is.large <- nn > 1e4
  ani.cl <- pam(ani.d, top.n, variant = "faster", do.swap = !is.large)
  ani.types <- ani.cl$clustering
  ani.medoids <- ani.cl$medoids

  # Classify excluded genome (for huge collections)
  if (is.huge) {
    say("Classifying excluded genomes")
    ani.d <- ani.d.ori
    # Find closest medoid for missing genomes
    missing <- labels(ani.d)[!labels(ani.d) %in% names(ani.types)]
    say("- Classify:", length(missing))
    for (i in missing) ani.types[i] <- which.min(ani.d.m[ani.medoids, i])
    # Reorder
    say("- Reorder and save")
    ani.types <- ani.types[labels(ani.d)]
    # Save missing genomes for inspection
    write.table(
      missing, paste0(out_base, ".missing.txt"),
      quote = FALSE, col.names = FALSE, row.names = FALSE
    )
  }

  # Build tree
  if (is.large) {
    say("Bypassing tree for large set")
    write.table(
      '{}', file = paste(out_base, ".nwk", sep = ""),
      col.names = FALSE, row.names = FALSE, quote = FALSE
    )
  } else {
    say("Tree")
    ani.ph <- bionj(ani.d)
    say("- Write")
    express.ori <- options("expressions")$expressions
    if(express.ori < ani.ph$Nnode * 4){
      options(expressions = min(c(5e7, ani.ph$Nnode * 4)))
    }
    write.tree(ani.ph, paste(out_base, ".nwk", sep = ""))
    options(expressions = express.ori)
  }

  # Generate graphic report
  say("Graphic report")
  pdf(paste(out_base, ".pdf", sep = ""), 7, 12)
  if (is.huge) {
    plot(NULL, axes = FALSE, xlab = '', ylab = '', xlim = 0:1, ylim = 0:1)
    legend('center', legend = 'Dataset too large for graphical representation')
  } else {
    layout(matrix(c(rep(1:3, each = 2), 4:5), byrow = TRUE, ncol = 2))
    plot_distances(ani.d)
    plot_silhouette(k, s[1, ], s[2, ], ds, top.n)
    plot_clustering(ani.cl, ani.d, ani.types)
    if (!is.large) plot_tree(ani.ph, ani.types, ani.medoids)
  }
  dev.off()

  # Save results
  write_text_report(out_base, ani.d, ani.medoids, ani.types)

  # Return data
  say("Cluster ready")
  return(list(
    ani.medoids = ani.medoids,
    ani.types = ani.types,
    ani.d = ani.d
  ))
}

#= Helper functions
say <- function (...) {
  message(paste("[", date(), "]", ..., "\n"), appendLF = FALSE)
}

generate_empty_files <- function (out_base) {
  pdf(paste(out_base, ".pdf", sep = ""), 7, 12)
  plot(1, t = "n", axes = F)
  legend("center", "No data", bty = "n")
  dev.off()
  file.create(paste(out_base, ".1.classif", sep = ""))
  file.create(paste(out_base, ".1.medoids", sep = ""))
}

write_text_report <- function (out_base, ani.d, ani.medoids, ani.types) {
  say("Text report")
  write.table(
    ani.medoids, paste(out_base, "medoids", sep = "."),
    quote = FALSE, col.names = FALSE, row.names = FALSE
  )
  classif <- cbind(names(ani.types), ani.types, ani.medoids[ani.types], NA)
  ani.d.m <- 100 - as.matrix(ani.d) * 100
  for (j in 1:nrow(classif)) {
    classif[j,4] <- ani.d.m[classif[j,1], classif[j,3]]
  }
  write.table(
    classif, paste(out_base, "classif", sep = "."),
    quote = FALSE, col.names = FALSE, row.names = FALSE, sep = "\t"
  )
}

plot_silhouette <- function (k, s, ns, ds, top.n) {
  # s
  par(mar = c(4,5,1,5)+0.1)
  plot(
    1, t = "n", xlab = "k (clusters)", ylab = "", xlim = range(c(0,k)),
    ylim = range(s), bty = "n", xaxs = "i", yaxt = "n"
  )
  polygon(c(k[1], k, k[length(k)]), c(0,s,0), border = NA, col = "grey80")
  axis(2, fg = "grey60", col.axis = "grey60")
  mtext("Mean silhouette", side = 2, line = 3, col = "grey60")

  # ns
  par(new = TRUE)
  plot(
    1, t = "n", bty = "n",
    xlab = "", ylab = "", xaxt = "n", yaxt = "n", xaxs = "i",
    xlim = range(c(0,k)), ylim = range(ns)
  )
  points(k, ns, type = "o", pch = 16, col = rgb(1/2,0,0,3/4))
  axis(4, fg = "darkred", col.axis = "darkred")
  mtext("Negative silhouette area", side = 4, line = 3, col = "darkred")

  # ds
  par(new = TRUE)
  plot(
    1, t = "n", bty = "n",
    xlab = "", ylab = "", xaxt = "n", yaxt = "n", xaxs = "i",
    xlim = range(c(0,k)), ylim = range(ds)
  )
  lines(k, ds)
  abline(v = top.n, lty = 2)
}

plot_distances <- function (dist) {
  par(mar = c(5,4,1,2) + 0.1)
  hist(
    dist, border = NA, col = "grey60", breaks = 50,
    xlab = "Distances", main = ""
  )
}

plot_clustering <- function (cl, dist, types) {
  par(mar = c(5,4,4,2) + 0.1)
  top.n <- length(cl$medoids)
  col <- ggplotColours(top.n)
  plot(silhouette(cl), col = col)
  dist.n <- length(labels(dist))
  if (dist.n <= 15 | dist.n > 4e4) {
    plot(1, type = "n", axes = FALSE, xlab = "", ylab = "", bty = "n")
    plot(1, type = "n", axes = FALSE, xlab = "", ylab = "", bty = "n")
  } else {
    ani.mds <- cmdscale(dist, k = 4)
    if (ncol(ani.mds) == 4) {
      plot(
        ani.mds[,1], ani.mds[,2], col = col[types], cex = 1/2,
	xlab = "Component 1", ylab = "Component 2"
      )
      plot(
        ani.mds[,3], ani.mds[,4], col = col[types], cex = 1/2,
	xlab = "Component 3", ylab = "Component 4"
      )
    }else{
      for (i in 1:2)
        plot(1, type = "n", axes = FALSE, xlab = "", ylab = "", bty = "n")
    }
  }
}

plot_tree <- function (phy, types, medoids) {
  layout(1)
  top.n <- length(unique(types))
  col <- ggplotColours(top.n)
  is.medoid <- phy$tip.label %in% medoids
  phy$tip.label[is.medoid] <- paste(
    phy$tip.label[is.medoid],
    " [", types[phy$tip.label[is.medoid]], "]",
    sep = ""
  )
  plot(
    phy, cex = ifelse(is.medoid, 1/3, 1/6),
    font = ifelse(is.medoid, 2, 1),
    tip.color = col[types[phy$tip.label]]
  )
}

ggplotColours <- function (n = 6, h = c(0, 360) + 15, alpha = 1) {
  if ((diff(h) %% 360) < 1) h[2] <- h[2] - 360 / n
  hcl(h = seq(h[1], h[2], length = n), c = 100, l = 65, alpha = alpha)
}

ani_distance <- function (ani_file, sel) {
  # Try to locate rda, then rds, and otherwise read gzipped table
  rda <- gsub("\\.txt\\.gz$", ".rda", ani_file)
  if (file.exists(rda)) {
    load(rda) # Should already contain `a`, `b`, and `d` as vectors
  } else {
    rds <- gsub("\\.txt\\.gz$", ".rds", ani_file)
    if (file.exists(rds)) {
      sim <- readRDS(rds)
    } else {
      sim <- read.table(
        gzfile(ani_file), sep = "\t", header = TRUE, as.is = TRUE
      )
    }

    # Extract individual variables to deal with very large matrices
    a <- sim$a
    b <- sim$b
    d <- 1 - (sim$value / 100)
  }
  
  # If there is no data, end process
  if (length(a) == 0) return(NULL)

  # Apply filter (if requested)
  ids <- NULL
  if (!is.na(sel) && file.exists(sel)) {
    say("Filter selection")
    ids <- read.table(sel, sep = "\t", head = FALSE, as.is = TRUE)[,1]
    sel.idx <- which(a %in% ids & b %in% ids)
    a <- a[sel.idx]
    b <- b[sel.idx]
    d <- d[sel.idx]
  } else {
    ids <- unique(c(a, b))
  }

  # Transform to dist object
  say("Distances")
  out <- matrix(
    min(max(d) * 1.2, 1.0), nrow = length(ids), ncol = length(ids),
    dimnames = list(ids, ids)
  )
  diag(out) <- 0
  # Split task to reduce peak RAM and support very large matrices
  # - Note that `k` is subsetting by index, but it's defined as numeric
  #   instead of integer. The reason is that integer overflow occurs
  #   at just over 2e9, whereas numerics can represent much larger
  #   numbers without problems
  i <- 0
  while (i < length(a)) {
    k <- seq(i + 1, min(i + 1e8, length(a)))
    out[cbind(a[k], b[k])] <- d[k]
    out[cbind(b[k], a[k])] <- d[k]
    i <- i + 1e8
  }
  return(as.dist(out))
}

#= Main
options(warn = 1)
if (length(argv) >= 5 & argv[5] == "empty") {
  generate_empty_files(argv[2])
  write.table(NULL, paste(argv[2], "medoids", sep = "."))
  write.table(NULL, paste(argv[2], "classif", sep = "."))
  write.table(date(), paste(argv[2], "ready", sep = "."))
}else{
  subclades(
    ani_file = argv[1],
    out_base = argv[2],
    thr = ifelse(is.na(argv[3]), 1, as.numeric(argv[3])),
    sel = argv[4]
  )
}

