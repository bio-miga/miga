# Distances

MiGA estimates distances (or similarities) between datasets using different
techniques.
Only genome-to-genome comparisons have been implemented,
including the genomes of isolates, metagenome-assembled genomes,
or single-cell amplified genomes.
No metagenome-to-metagenome or genome-to-metagenome distances are currently
available in MiGA.

## Hierarchical approach to distances

For any given pair of genomes, MiGA attempts a hierarchical approach to identify
the most appopriate metric of similarity:
1. First, the genomes are compared using [hAAI](#haai). If this method is
   skipped, if it fails, or if the value is greater than 90%, MiGA continues to
   step 2. Otherwise, this value is used to estimate the AAI and both values are
   recorded.
2. Next, MiGA compares genomes using [AAI](#aai). Whenever the AAI is 85% or
   higher, MiGA continues to step 3.
3. Finally, MiGA estimates [ANI](#ani).

## hAAI

**Heuristic Average Amino Acid Identity**.
The hAAI is the average amino acid identity between the highly conserved
proteins of two genomes, as identified by
[essential genes](../part5/workflow.md#essential-genes).
It is used to estimate AAI for distant pairs, but it looses resolution between
close relatives.
This metric is completely bypassed in projects of
[type clade](../part2/types.md#clade) as well as projects with the
[metadata field](../part5/metadata.md#projects) `haai_p=no`.
This field also controls the Software used: `blast+` (default), `blast`, `blat`,
or `diamond`.

## AAI

**Average Amino Acid Identity**.
The AAI is the average amino acid identity between all proteins of two genomes,
as identified by [cds](../part5/workflow.md#cds).
When running this analysis, the intermediate reciprocal best matches (RBMs) are
also stored in projects of [type clade](../part2/types.md#clade).
This feature can be turned off to save storage space or forced to be on in any
project type using the [metadata field](../part5/metadata.md#projects)
`aai_save_rbm=false` or `aai_save_rbm=true`, respectively.
The Software used as search engine can be controlled using the
[metadata field](../part5/metadata.md#projects) `haai_p`: `blast+` (default),
`blast`, `blat`, or `diamond`.
[Workflows](../part6.md) use `blast+` by default, or `diamond` if the flag
`--fast` is passed (whenever available).

## ANI

**Average Nucleotide Identity**.
The ANI is the average nucleotide identity between fragments of two genomes.
The Software used as search engine can be controlled using the
[metadata field](../part5/metadata.md#projects) `haai_p`: `blast+` (default),
`blast`, `blat`, or `fastani`.
[Workflows](../part6.md) use `blast+` by default, or `fastani` if the flag
`--fast` is passed (whenever available).

## SQLite3 schema

The information on the different similarity metrics above is stored in SQLite3
database files. The general schema for [hAAI](#haai) and [AAI](#aai) is:

```sql
CREATE TABLE aai(
  seq1 varchar(256), seq2 varchar(256), aai float, sd float, n int, omega int
);
CREATE TABLE rbm(
  seq1 varchar(256), seq2 varchar(256), id1 varchar(256), id2 varchar(256),
  id float, evalue float, bitscore float
);
```

The `aai` table holds the metric values, including: the name of the genomes
compared `seq1` and `seq2`, the AAI or hAAI as percentage `aai`, the
standard deviation across proteins when available `sd`, the total number
of RBMs `n`, and the smaller number of proteins from the two genomes `omega`.
The `rbm` table holds the RBMs for [AAI](#aai) (whenever available if stored)
and is always empty for [hAAI](#haai).

The general schema for [ANI](#ani) is:

```sql
CREATE TABLE ani(
  seq1 varchar(256), seq2 varchar(256), ani float, sd float, n int, omega int
);
CREATE TABLE rbm(
  seq1 varchar(256), seq2 varchar(256), id1 int, id2 int, id float,
  evalue float, bitscore float
);
CREATE TABLE regions(
  seq varchar(256), id int, source varchar(256), `start` int, `end` int
);
```

The `ani` table holds the metric values, including: the name of the genomes
compared `seq1` and `seq2`, the ANI as percentage `ani`, the standard deviation
across fragments when available `sd`, the total number of RBM fragments `n`,
and the smaller number of fragments from the two genomes `omega`.
The tables `rbm` and `regions` are always empty.

