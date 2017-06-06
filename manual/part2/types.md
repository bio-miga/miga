# MiGA types

MiGA has predefined settings and analyses. In order to maximize simplicity and
reproducibility while ensuring a wide array of use cases, MiGA uses presets
called "types". There are different [types of projects](#project-types) and
[types of datasets](#dataset-types):

## Project types

When you create a project, the type of project defines which project-wide
analyses are going to be executed (and how). The different types are:

### Mixed

A mixed collection of genomes, metagenomes, and viromes. This is the most basic
type of project, with no support for any project-wide analyses. It is intended
for projects that are only concerned with datasets preprocessing, *e.g.*, read
trimming, assembly, etc.

### Genomes

A collection of genomes. This is the most typical type of project, storing a set
of genomes from different taxonomic groups. It can be useful for anything from
indexing a reference database, to create a collection of metagenomic bins, and
anything in between.

### Clades

A collection of closely-related genomes (ANI >= 90%). This is a project for a
collection of genomes in the same species (or closely-related species) that
require higher resolution but don't require support for a large distance range.

### Metagenomes

A collection of metagenomes and/or viromes. This is an experimental type,
currently identical to [Mixed](#mixed).

## Dataset types

Once you have a project, the type of the datasets define which analyses are
going to be executed for that particular entry (and how). The different types
are:

### Genome

The genome from an isolate. This is the most typical case, in which you have
a genomes (complete or draft) from a pure culture (excluding SGA).

### Single-cell genome

A Single-cell Genome Amplification (SGA). This is the particular case in which
you are dealing with an amplified genome from a single cell. These datasets
typically have very uneven coverage (resulting in very incomplete assemblies)
and sometimes have contamination from external DNA.

### Population genome

A population genome (including metagenomic bins). This is the type of datasets
that include sequences from different strains of the same species, such as
metagenomic bins or metagenomes of highly enriched (but not pure) cultures.

### Metagenome

A metagenome (excluding viromes).

### Virome

A viral metagenome.
