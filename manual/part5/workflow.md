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

This step corresponds to *Assembly* in the diagram above, and assembles trimmed
FastA reads using [IDBA-UD](external.md#idba-ud).

Supported file keys:

* `largecontigs` (*req*): FastA file containing large contigs or scaffolds
  (>500bp).
* `allcontigs`: FastA file containing all contigs or scaffolds (including
  large).
* `assembly_data` (*dir*): Folder containing some intermediate files generated
  during the assembly.

MiGA symbol: `assembly`.

## CDS



## Essential Genes

## SSU

## MyTaxa

## MyTaxa Scan

## Distances

## Stats

# Project Results

## hAAI Distances

## AAI Distances

## ANI Distances

## Clade Finding

## Subclades

## OGS

## Project Stats

[workflow]: ../img/arch_v06.png "The MiGA Workflow"
