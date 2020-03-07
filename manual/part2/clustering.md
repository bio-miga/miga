# Clustering

MiGA generates a clustering-based indexing of databases using ANI distances
(for clade projects) or AAI distances (for all other projects). This indexing
enables quickly searching databases with query genomes.

## General algorithm

The AAI or ANI values are transformed to distances (1 - identity), and the
all-vs-all distance matrix is used to generate a *k*-medoids partition
(PAM: Partition Around Medoids).
*k* is selected to simultaneously optimize for maximum Silhouette average width
and minimum Silhouette negative area, between 2 and 100 (or the number of
genomes minus 1, whichever is smaller).
Once the partitions are defined, the same algorithm is applied recursively
to each partition with 8 or more genomes.
The resulting clustering-based indexing is used to speed-up query searches.
In some cases it can also be used as *de novo* typing scheme, in particular
for ANI distances (clade projects).

## Genomospecies proposals

In addition to the above clustering-based indexing, MiGA clusters genomes by
Markov Clustering (MCL) using all ANI values above 95% as edges.
The result is a collection of discrete genomospecies.
The list of genomes per genomospecies is sorted by medoid-ranking, in which
the first genome has the minimum average distance to all other genomes in the
genomospecies.

