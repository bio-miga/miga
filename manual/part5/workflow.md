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

MiGA symbol: `trimmed_fasta`.

## Assembly

In this step MiGA assembles trimmed FastA reads using
[IDBA-UD](external.md#idba-ud).

Supported file keys:

* `largecontigs` (*req*): FastA file containing large contigs or scaffolds
  (>500bp).
* `allcontigs`: FastA file containing all contigs or scaffolds (including
  large).
* `assembly_data` (*dir*): Folder containing some intermediate files generated
  during the assembly.

MiGA symbol: `assembly`.

## CDS

This step corresponds to *Gene prediction* in the diagram above. MiGA predicts
coding sequences (putative genes and proteins) using
[Prodigal](external.md#prodigal).

Supported file keys:

* `proteins` (*req*): FastA file containing translated protein sequences.
* `genes` (*req*): FastA file containing putative gene sequences.
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
  from *essential* genes.
* `collection` (*req*): Folder containing individual FastA files with protein
  translations from *essential* genes.
* `report` (*req*): Raw text report including derived statistics, as well as
  *essential* genes missing or detected in multiple copies (for genomes) or
  copy counts (for metagenomes and viromes).

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
* `wintax` (*req*): Taxonomic distribution of each window.
* `blast` (*gz*): BLAST against the reference genomes database.
* `mytaxain` (*gz*): Re-formatted BLAST used as input for MyTaxa.
* `report` (*req*): PDF file containing the graphic report.
* `regions` (*dir*): Folder containing FastA files with the sequences of the
  genes in regions identified as abnormal.
* `gene_ids`: List of genes per window.
* `region_ids`: List of regions identified as abnormal.
* `nomytaxa`: If it exists, MiGA assumes no support for MyTaxa modules, and none
  of the above files are required.

MiGA symbol: `mytaxa_scan`.

## Distances

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `distances`.

## Stats

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `stats`.

# Project Results

## hAAI Distances

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `haai_distances`.

## AAI Distances

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `aai_distances`.

## ANI Distances

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `ani_distances`.

## Clade Finding

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `clade_finding`.

## Subclades

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `subclades`.

## OGS

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `ogs`.

## Project Stats

**Upcoming Additional Information**

Supported file keys:

...

MiGA symbol: `project_stats`.

[workflow]: ../img/arch_v06.png "The MiGA Workflow"
