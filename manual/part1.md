# Part I: What is MiGA?

MiGA is a [data management](#data-management) and [processing](#processing)
system for [microbial genomes and metagenomes](#data-types). It's main aim is
to provide a [uniform system](#standards) for
[genome-based taxonomic classification](#taxonomy) and [diversity](#diversity)
studies, but its base can be used for [other purposes](#more).

## Data management

MiGA organizes your data in consistent, well-organized way independent of
centralized databases. This makes MiGA projects the ideal system to store data
even if you don't use MiGA for anything else. MiGA is completely based on
filesystem structures, so it can easily be transferred, backed-up, and long-term
stored. Moreover, MiGA projects can be easily browsed, with descriptive folder
names and a simple structure that is easy to understand.

**MiGA is not**: MiGA is not designed to support versioning or database storage,
other than individual file-based databases, in order to keep the overhead on 
any of the tasks above (and the system requirements) at a minimum.

## Processing

MiGA performs general-purpose analyses to pre-process genomic and metagenomic
data. The main purpose of MiGA is [genome-based taxonomy](#taxonomy), but some
pre-processing step are necessary anyway, so they can be used for many other
purposes. For example, the initial data in most genomic and metagenomic projects
is sequencing data. For almost any project, that means that trimming, clipping,
and read quality assessment are necessary steps for any downstream analyses.
In most cases, assembly and gene prediction are also necessary, and other
analyses like rRNA and essential genes detection is very useful. All of this is
automatically done by MiGA!

**MiGA is not**: MiGA only supports short-read data (and it's optimized for
Illumina data). MiGA's aim is to keep analyses as simple and standardized as
possible, so almost no customization is supported. MiGA is not a workflow
manager system.

## Data types

MiGA is designed to process genomes, and can handle metagenomes (with some
restrictions). In any case, MiGA is optimized for short-read datasets, or
alternatively already assembled datasets. MiGA is optimized to process
prokaryotic data (Archaeal and Bacterial), but it has some readily available
customizations for viral metagenomes (or viromes).

**MiGA is not**: No customizations are currently available for eukaryotic
or viral genomes, nor for transcriptomic data. The data management design
(and perhaps some of the processing steps) can be used for these and other
purposes, but thread carefully.

## Standards

MiGA has a general-purpose design, with some presets designed for the different
[data types](../part2/types.md) supported. All the internal configuration and
metadata are stored as individual JSON files. Sequence quality is stored as
FastQ, and sequences are stored as FastA, and these two cover most of the data
in the system. There are also some graphic reports in PDF and HTML, raw-text
reports and logs, and a few general statistics in JSON. Finally, all of the
[pair-wise comparisons](../part2/distances.md) are stored in SQLite3 files
[described here](../part2/distances.md#sqlite3-schema).

### Filesystem structure

+ **daemon/**: Daemons lair.
  + **daemon.json**: Daemon settings.
  + ...: Several daemon log files.
+ **data/**: All the data is stored here.
  + **01.raw_reads/**: Raw reads in FastQ format.
  + **02.trimmed_reads/**: Trimmed/clipped reads in FastQ format.
  + **03.read_quality/**: Read quality reports in HTML and PDF formats.
  + **04.trimmed_fasta/**: Trimmed/clipped and interposed reads in FastA format.
  + **05.assembly/**: Assemblies in FastA format.
  + **06.cds/**: Gene predictions in FastA (genes and proteins) and GFF formats.
  + **07.annotation/**: Data annotations.
    + **01.function/**: Functional annotations.
      + **01.essential/**: Essential prokaryotic gene detections.
      + **02.ssu/**: Ribosomal RNA (small subunit) sequence annotations.
    + **02.taxonomy/**: Taxonomic annotations.
      + **01.mytaxa/**: MyTaxa fragment annotations.
    + **03.qa/**: Quality assessments.
      + **01.checkm/**: (Currently not in use).
      + **02.mytaxa_scan/**: Gene-window assessment of taxonomic distributions.
  + **08.mapping/**: (Currently not in use).
  + **09.distances/**: Pair-wise comparisons.
    + **01.haai/**: Heuristic Average Amino Acid Identity (essential proteins).
    + **02.aai/**: Average Amino Acid Identity (all proteins).
    + **03.ani/**: Average Nucleotide Identity (genomic fragments).
    + **04.ssu/**: (Currently not in use).
  + **10.clades/**: Dataset clustering at various resolution levels.
    + **01.find/**: Identification of naturally-forming AAI clades at species
      level and above.
    + **02.ani/**: Identification of naturally-forming ANI clades at species
      level and below.
    + **03.ogs/**: Extraction of orthologous groups of proteins and pan-genome
      statistics.
    + **04.phylogeny/**: (Currently not in use).
    + **05.metadata/**: (Currently not in use).
+ **metadata/**: Collection of JSON files with datasets metadata.
+ **miga.project.json**: JSON file with project metadata.

## Taxonomy

MiGA's ultimate goal is to provide a standardized set of tools for consistent
genome-wide taxonomic analyses. For this reason, MiGA **does not** provide nor
favors any one taxonomic database. This *authority-agnostic* approach allows us
to focus on the underlying analyses, supporting as many schemas as possible.
With this said, MiGA does support automated taxonomy annotation for some
databases in EBI and NCBI linked to NCBI Taxonomy, and it does support some
automated adjustments for the JGI schema (in particular for metagenomes).
Instead of forcing groups by external taxonomies that may have varying degrees
of accuracy and completeness, MiGA follows a data-driven clustering based on
[naturally-forming groups](part2/clustering.md) based on AAI and ANI analyses.
Hence, MiGA projects can be used to classify novel genomes using any reference
taxonomy (or none!).

**MiGA is not**: MiGA does not provide nor endorse any particular taxonomic
authority.

## Diversity

MiGA can catalogue datasets, even in the absence of a reference taxonomy. This
allows many advanced analyses, including (but not restricted to):

* Phylogenomic reconstructions using
  [orthologous groups of proteins](part5/workflow.md#ogs).
* Multi-Locus sequence analysis using
  [essential genes](part5/workflow.md#essential-genes).
* Characterization of collections of
  [single-cell](part2/types.md#single-cell-genome) or
  [population](part2/types.md#population-genome) genomes
* Characterization of
  [intra-population diversity](part2/clustering.md#ani-clades).
* [Metagenome](part2/types.md#metagenome) or [virome](part2/types.md#virome)
  analyses.

## More

The [intermediate analyses](part5/workflow.md) performed by MiGA can be used for
many other purposes. For example, we use MiGA's initial pre-processing (like
[read trimming](part5/workflow.md#trimmed_reads)/[quality check](part5/workflow.md#read_quality),
[assembly](part5/workflow.md#assembly), and
[gene prediction](part5/workflow.md#cds) in most of our genomic and metagenomic
projects.
