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



## Standards



## Taxonomy



## Diversity



## More


