# MiGA Workflow

This is the general overview of the MiGA workflow:

![MiGA Workflow][workflow]

For each step, performed analyses may include the use of external Software, and
produce one or more result files (indexed in a hash). In most steps, different
utilities from the [Enveomics Collection](external.md#enveomics-collection) are
used in addition to the Software detailed below. See more details of each
step below, including file keys and descriptions. Some files are mandatory to
continue with the analysis (marked with *req*), some can be gzipped during or
after the analysis (marked with *gz*), and some are directories (marked with
*dir*).

# Dataset Results

## Raw Reads

This step is never actually performed by MiGA, instead it serves as the entry
point for raw reads input.

Supported file keys:

* **For single reads only**
  * `single` (*req*, *gz*): FastQ file containing the raw reads.
* **For paired-end reads only**
  * `pair1` (*req*, *gz*): FastQ file containing the raw forward reads.
  * `pair2` (*req*, *gz*): FastQ file containing the raw reverse reads.

Statistics:

* **For single reads only**
  * `reads`: Total number of reads.
  * `length_average`: Average read length (in bp).
  * `length_standard_deviation`: Standard deviation of read length (in bp).
  * `g_c_content`: G+C content of all reads (in %).
* **For paired-end reads only**
  * `read_pairs`: Total number of read pairs.
  * `forward_length_average`: Average forward read length (in bp).
  * `forward_length_standard_deviation`: Standard deviation of forward read
    length (in bp).
  * `forward_g_c_content`: G+C content of forward reads (in %).
  * `reverse_length_average`, `reverse_length_standard_deviation`,
    `reverse_g_c_content`: Same as above, for reverse reads.

MiGA symbol: `raw_reads`.

## Trimmed Reads

This is part of *Trimming & read quality* in the above diagram. In this step,
MiGA trims reads by Phred quality score 20 (Q20) and minimum length of 50bp
using [SolexaQA++](external.md#solexaqa), and clips potential adapter
contamination using [Scythe](external.md#scythe) (reapplying the length filter).
If the reads are paired, only pairs passing the filters are used.

Supported file keys:

* **For single reads only**
  * `single` (*req*, *gz*): FastQ file containing trimmed/clipped reads.
* **For paired-end reads only**
  * `pair1` (*req*, *gz*): FastQ file containing trimmed/clipped forward reads.
  * `pair2` (*req*, *gz*): FastQ file containing trimmed/clipped reverse reads.
  * `single` (*req*, *gz*): FastQ file containing trimmed/clipped reads with
    only one sister passing quality control.
* **For either type**
  * `trimming_summary`: Raw text file containing a summary of the trimmed
    sequences.

MiGA symbol: `trimmed_reads`.

## Read Quality

This is a quality-control step included as part of *Trimming & read quality* in
the diagram above. In this step, MiGA generates quality reports of the
trimmed/clipped reads using [SolexaQA++](external.md#solexaqa) and
[FastQC](external.md#fastqc).

Supported file keys:

* `solexaqa` (*dir*): Folder containing the SolexaQA++ quality-control
  summaries.
* `fastqc` (*dir*): Folder containing the FastQC quality-control analyses.

MiGA symbol: `read_quality`.

## Trimmed FastA

This is the final step included in *Trimming & read quality* in the diagram
above, in which MiGA generates FastA files with the trimmed/clipped reads.

Supported file keys:

* `coupled` (*req* for coupled reads, unless `pair1` and `pair2` exist):
  Interposed FastA file containing quality-checked paired reads. If this file
  doesn't exist, it is automatically generated from `pair1` and `pair2`.
* `single` (*req* for single reads, *gz* for coupled reads): FastA file with
  quality-checked single-end reads.
* `pair1` (*gz*): FastA file containing forward sisters of quality-checked
  paired-end reads.
* `pair2` (*gz*): FastA file containing reverse sisters of quality-checked
  paired-end reads.

Statistics:

* `reads`: Total number of reads.
* `length_average`: Average read length (in bp).
* `length_standard_deviation`: Standard deviation of read length (in bp).
* `g_c_content`: G+C content of all reads (in %).

MiGA symbol: `trimmed_fasta`.

## Assembly

In this step MiGA assembles trimmed FastA reads using
[IDBA-UD](external.md#idba-ud).

Supported file keys:

* `largecontigs` (*req*): FastA file containing large contigs or scaffolds
  (>1Kbp).
* `allcontigs`: FastA file containing all contigs or scaffolds (including
  large).
* `assembly_data` (*dir*): Folder containing some intermediate files generated
  during the assembly.

Statistics:

* `contigs`: Total number of (large) contigs.
* `n50`: N50 of (large) contigs (in bp).
* `total_length`: Total length of (large) contigs (in bp).
* `g_c_content`: G+C content of (large) contigs (in %).

MiGA symbol: `assembly`.

## CDS

This step corresponds to *Gene prediction* in the diagram above. MiGA predicts
coding sequences (putative genes and proteins) using
[Prodigal](external.md#prodigal).

Supported file keys:

* `proteins` (*req*): FastA file containing translated protein sequences.
* `genes`: FastA file containing putative gene sequences.
* `gff3` (*gz*): GFF v3 file containing the coordinates of coding sequences.
  This file is not required, but [MyTaxa](#mytaxa) depends on it (or `gff2` or
  `tab`, whichever is available).
* `gff2` (*gz*): GFF v2 file containing the coordinates of coding sequences.
  This file is not produced by MiGA, but it's supported for backwards
  compatibility with earlier versions using MetaGeneMark.
* `tab` (*gz*): Tabular-delimited file containing the columns: gene ID, gene
  length, and contig ID. This file is not produced by MiGA, but it's supported
  to allow [MyTaxa](#mytaxa) to run when more detailed information about the
  gene prediction is missing.

Statistics:

* `predicted_proteins`: Total number of predicted proteins.
* `average_length`: Average length of predicted proteins (in aa).
* `coding_density`: Coding density of the genome (in %).

MiGA symbol: `cds`.

## Essential Genes

In this step, MiGA uses `HMM.essential.rb` from the
[Enveomics Collection](external.md#enveomics-collection) to identify a set of
genes typically present in single-copy in Bacterial and Archaeal genomes. In
this step, protein translations of those *essential* genes are extracted for
other analyses in MiGA (*e.g.*, hAAI in [distances](#distances)) or outside
(*e.g.*, phylogeny or MLSA for [diversity analyses](../part1.md#diversity)). In
addition, this step generates a report that can be used for quality control
including estimations of completeness and contamination (for genomes) and
median number of copies of single-copy genes (for metagenomes and viromes).

Supported file keys:

* `ess_genes` (*req*): FastA file containing all extracted protein translations
  from *essential* genes (.faa) or archived collection (proteins.tar.gz).
* `collection` (*req*): Folder containing individual FastA files with protein
  translations from *essential* genes.
* `report` (*req*): Raw text report including derived statistics, as well as
  *essential* genes missing or detected in multiple copies (for genomes) or
  copy counts (for metagenomes and viromes).
* `bac_report`: If present, this is the original report, and it indicates that a
  corrected report has been generated to accomodate particular features of the
  dataset.

Statistics:

* **For metagenomes and viromes**
  * `mean_copies`: Average copy number across essential genes.
  * `median_copies`: Median copy number across essential genes.
* **For genomes**
  * `completeness`: Estimated completeness of the genome, based on presence of
    essential genes (in %).
  * `contamination`: Estimated contamination of the genome, based on copy number
    of essential genes (in %).
  * `quality`: Completeness - 5 x Contamination.

MiGA symbol: `essential_genes`.

## SSU

In this step, MiGA detects small-subunit rRNA genes (16S) using
[Barrnap](external.md#barrnap) and extracts their sequences using
[Bedtools](external.md#bedtools).

Supported file keys:

* `longest_ssu_gene` (*req*): FastA file containing the longest detected SSU
  gene.
* `gff` (*gz*): GFF v3 file containing the location of detected SSU genes.
* `all_ssu_genes` (*gz*): FastA file containing all the detected SSU genes.

MiGA symbol: `ssu`.

## MyTaxa

This step is only supported for metagenomes and viromes, and it requires the
(optional) MyTaxa [requirements installed](../part2/requirements.md).

In this step, the most likely taxonomic classification of each contig is
identified using [MyTaxa](external.md#mytaxa), and a report is generated using
[Krona](external.md#krona).

Supported file keys:

* `mytaxa` (*req*): Output generated by MyTaxa.
* `blast` (*gz*): BLAST against the reference genomes database.
* `mytaxain` (*gz*): Re-formatted BLAST used as input for MyTaxa.
* `nomytaxa`: If it exists, MiGA assumes no support for MyTaxa modules, and none
  of the above files are required.
* `species`: Profile of species composition (in permil) as raw tab-delimited
  text.
* `genus`: Profile of genus composition (in permil) as raw tab-delimited text.
* `phylum`: Profile of phylum composition (in permil) as raw tab-delimited text.
* `innominate`: List of innominate taxa (groups without a name but containing
  lower-rank classifications) as raw text.
* `kronain`: Raw-text list of taxa used as input for Krona.
* `krona`: HTML output produced by Krona.

MiGA symbol: `mytaxa`.

## MyTaxa Scan

This step is only supported for genomes (dataset types genome, popgenome, and
scgenome), and it requires the (optional) MyTaxa
[requirements installed](../part2/requirements.md).

In this step, the genomes are scanned in windows of ten genes. For each window,
the taxonomic distribution is determined using [MyTaxa](external.md#mytaxa) and
compared against the distribution for the entire genome. This is a
quality-control step for manual curation.

Supported file keys:

* `mytaxa` (*req*): MyTaxa output.
* `report` (*req*): PDF file containing the graphic report.
* `regions_archive` (*gz*): Archived folder containing FastA files with the
  sequences of the genes in regions identified as abnormal.
* `nomytaxa`: If it exists, MiGA assumes no support for MyTaxa modules, and none
  of the above files are required.

Deprecated file keys:

* `wintax`: Taxonomic distribution of each window.
* `blast` (*gz*): BLAST against the reference genomes database.
* `mytaxain` (*gz*): Re-formatted BLAST used as input for MyTaxa.
* `regions` (*dir*): Folder containing FastA files with the sequences of the
  genes in regions identified as abnormal.
* `gene_ids`: List of genes per window.
* `region_ids`: List of regions identified as abnormal.

MiGA symbol: `mytaxa_scan`.

## Distances

This step is only supported for genomes
([dataset types](../part2/types.md#dataset-types) genome, popgenome, and
scgenome). In this step, each dataset is compared against all other datasets
in the project. If the dataset is a
[reference dataset](../part2/types.md#query-vs-reference-datasets), it is
compared against all other reference datasets in the project. If it's a query
dataset, it is compared iteratively against medoids. For more details on the
strategy used in this step, see the manual
[section on distances](../part2/distances.md).

Supported file keys:

* **For reference datasets**
  * `haai_db` (*req*): SQLite3 database containing hAAI values.
  * `aai_db`: SQLite3 database containing AAI values.
  * `ani_db`: SQLite3 database containing ANI values.
* **For query datasets**
  * `aai_medoids` (*req* except for clades projects): Best hits among medoids
    at different hierarchical levels in the AAI indexing.
  * `ani_medoids` (*req* for clades projects): Best hits among medoids at
    different hierarchical levels in the ANI indexing.
  * `haai_db` (*req*): SQLite3 database containing hAAI values.
  * `aai_db`: SQLite3 database containing AAI values.
  * `ani_db`: SQLite3 database containing ANI values.
  * `ref_tree`: Newick file with the Bio-NJ tree including queried medoids and
    the query dataset.
  * `ref_tree_pdf`: PDF rendering of `ref_tree`.
  * `intax`: Raw text result of the taxonomy test against the reference genome.

MiGA symbol: `distances`.

## Taxonomy

This step is only supported for genomes
([dataset types](../part2/types.md#dataset-types) genome, popgenome, and
scgenome) that are
[reference datasets](../part2/types.md#query-vs-reference-datasets), in projects
with a set reference project (`:ref_project` in metadata).

In this step, MiGA compares the genome against a reference project using the
query search method, and imports the resulting taxonomy with p-value below 0.05
(or whichever value is set as `:tax_pvalue` in metadata).

Supported file keys:
* `intax`: Raw text result of the taxonomy test against the reference genome.
* `aai_medoids` (*req* except for reference clades projects): Best hits among
  medoids at different hierarchical levels in the AAI indexing.
* `ani_medoids` (*req* for reference clades projects): Best hits among medoids
  at different hierarchical levels in the ANI indexing.
* `haai_db` (*req*): SQLite3 database containing hAAI values.
* `aai_db`: SQLite3 database containing AAI values.
* `ani_db`: SQLite3 database containing ANI values.
* `ref_tree`: Newick file with the Bio-NJ tree including queried medoids and
  the query dataset.
* `ref_tree_pdf`: PDF rendering of `ref_tree`.

MiGA symbol: `taxonomy`.

## Stats

In this step, MiGA traces back all the results of the dataset and estimates
summary statistics. In addition, it cleans any stored values in the distances
database including datasets no longer registered in the project.

No supported file keys.

MiGA symbol: `stats`.

# Project Results

Once all datasets have been pre-processed (*i.e.*, once all the results above
are available for all reference datasets), MiGA executes the following
project-wide steps:

## hAAI Distances

Consolidation of hAAI distances.

Supported file keys:

* `rdata` (*req*): Pairwise values in a `data.frame` for `R`.
* `matrix` (*req*): Pairwise values in a raw tab-delimited file.
* `log` (*req*): List of datasets included in the matrix.
* `hist`: Histogram of hAAI values as raw tab-delimited file.

MiGA symbol: `haai_distances`.

## AAI Distances

Consolidation of AAI distances.

Supported file keys:

* `rdata` (*req*): Pairwise values in a `data.frame` for `R`.
* `matrix` (*req*): Pairwise values in a raw tab-delimited file.
* `log` (*req*): List of datasets included in the matrix.
* `hist`: Histogram of AAI values as raw tab-delimited file.

MiGA symbol: `aai_distances`.

## ANI Distances

Consolidation of ANI distances.

Supported file keys:

* `rdata` (*req*): Pairwise values in a `data.frame` for `R`.
* `matrix` (*req*): Pairwise values in a raw tab-delimited file.
* `log` (*req*): List of datasets included in the matrix.
* `hist`: Histogram of ANI values as raw tab-delimited file.

MiGA symbol: `ani_distances`.

## Clade Finding

This step is only supported for project types
[genomes](../part2/types.md#genomes) and [clade](../part2/types.md#clade).

In this step, MiGA attempts to identify clades at species level or above using
a combination of ANI and AAI values. MiGA generates
[AAI clades](../part2/clustering.md#aai-clades) in this step for
[genomes projects](../part2/types.md#genomes). Clades proposed at AAI > 90% and
ANI > 95% are formed using the Markov Clustering algorithm implemented in
[MCL](external.md#mcl). Most distance manipulation and tree estimation and
manipulation utilities use the R packages [Ape](external.md#ape) and
[Vegan](external.md#vegan).

Supported file keys:

* `report` (*req* for `genomes`): PDF file including a graphic report for the
  clustering.
* `class_table` (*req* for `genomes`): Tab-delimited file containing the
  classification of all datasets in AAI clusters.
* `class_tree` (*req* for `genomes`): Newick file containing the classification
  of all datasets in AAI clusters as a dendrogram.
* `classif` (*req* for `genomes`): Tab-delimited file containing the
  highest-level classification of each dataset, the medoid of the cluster, and
  the AAI against the corresponding medoid.
* `medoids` (*req* for `genomes`): List of medoids per cluster.
* `aai_tree`: Bio-NJ tree based on AAI distances in Newick format.
* `proposal` (*req*): Proposed species-level clades in the project, based on
  `clades_ani95`. One line per proposed clade, with tab-delimited dataset names.
  Only clades with 5 or more members are included.
* `clades_aai90`: Clades formed at AAI > 90%. One clade per line, with
  comma-delimited dataset names.
* `clades_ani95`: Clades formed at ANI > 95%. One clade per line, with
  comma-delimited dataset names.
* `medoids_ani95`: List of `clades_ani95` datasets with the smallest ANI
  distance to all members of its own ANI95 clade. The list is in the same order.

MiGA symbol: `clade_finding`.

## Subclades

This step is only supported for project type [clade](../part2/types.md#clade).

In this step, MiGA attempts to identify clades below species level using ANI
values. MiGA generates [ANI clades](../part2/clustering.md#ani-clades) in this
step. Most distance manipulation and tree estimation and manipulation utilities
use the R packages [Ape](external.md#ape) and [Vegan](external.md#vegan).

Supported file keys:

* `report` (*req*): PDF file including a graphic report for the clustering.
* `class_table` (*req*): Tab-delimited file containing the classification of all
  datasets in ANI clusters.
* `class_tree` (*req*): Newick file containing the classification of all
  datasets in ANI clusters as a dendrogram.
* `classif` (*req*): Tab-delimited file containing the highest-level
  classification of each dataset, the medoid of the cluster, and
  the ANI against the corresponding medoid.
* `medoids` (*req*): List of medoids per cluster.
* `ani_tree`: Bio-NJ tree based on AAI distances in Newick format.

MiGA symbol: `subclades`.

## OGS

This step is only supported for project type [clade](../part2/types.md#clade).

In this step, MiGA generates groups of orthology using reciprocal best matches
between all pairs of datasets in the project. Groups are generated using
[MCL](external.md#mcl) with pairs weighted by bit score. Once computed, MiGA
uses the matrix of OGS to estimate summary and rarefied statistics.

Supported file keys:

* `ogs` (*req*): Matrix of orthology groups, as tab-delimited raw file.
* `stats` (*req*): Summary statistics in JSON format.
* `abc` (*gz*): When available, it includes all the individual RBM files in
  ABC format. This file is typically produced as intermediate result and
  removed before finishing, but can be maintained using
  `miga new -P . -m clean_ogs=false --update` in the project folder using the
  [CLI](../part3/CLI.md).
* `core_pan`: Summary statistics of rarefied core-genome/pangenome sizes in
  tab-delimited format.
* `core_pan_plot`: Plot of rarefied core-genome/pangenome sizes in PDF.

MiGA symbol: `ogs`.

## Project Stats

In this step, MiGA traces back all the results of the project and estimates
summary statistics.

Supported file keys:

* `taxonomy_index` (*req*): Index of datasets per taxonomy in JSON format.
* `metadata_index` (*req*): Searchable index of datasets metadata as SQLite3
  database.

MiGA symbol: `project_stats`.

[workflow]: ../img/arch_v07.png "The MiGA Workflow"
