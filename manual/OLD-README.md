MiGA: Microbial Genomes Atlas
=============================

Getting started with MiGA
-------------------------

### MiGA Interfaces

You caninteract with MiGA through different interfaces. These interfaces have
different purposes, but they also have some degree of overlap, because different
users with different aims sometimes want to do the same thing. Throughout this
manual I'll be telling you how to do things using mostly the CLI, but I'll also
try to mention the GUI and the Web Interface. The CLI is the most comprehensive
and flexible interface, but the other two are friendlier to humans. There is a
fourth interface that I won't be mentioning at all, but I'll try to document:
the Ruby API. MiGA is mostly written in Ruby, with an object-oriented approach,
and all the interfaces are just thin layers atop the Ruby core. That means that
you can write your own interfaces (or pieces) if you know how to talk to these
Ruby objects. Sometimes I even use `irb`, which is an interactive shell for
Ruby, but that's mostly for debugging.

#### MiGA CLI

CLI stands for Command Line Interface. This is a set of little scripts that let
you talk with MiGA through the terminal shell. If MiGA is in your PATH (see
[installation details](./INSTALLATION.md#miga-in-your-path)), you can simply run
`miga` in your terminal, and the help messages will take it from there. All the
MiGA CLI calls look like:

```bash
miga task [options]
```

Where `task` is one of the supported tasks and `[options]` is a set of dash-flag
options supported by each task. `-h` is always there to provide help. If you're
a MiGA administrator, this is probably the most convenient option for you (but
hey, give the GUI a chance).

#### MiGA GUI

The Graphical User Interface is the friendlier option for setting up a MiGA
project. It doesn't have as many options as the CLI, but it's pretty easy to
use, so it's a good option if you have a typical project in your hands.

#### MiGA Web

The Web interface for MiGA is the way MiGA reports results from a project. It's
not designed to set up new projects, but to explore existing ones, and to submit
non-reference datasets for analyses.

### Creating your first project

You can do this in the GUI, but I like the CLI better, so I'll be telling you
how to tell MiGA what to do from the CLI. First, think where you'll place your
project. Normally this means a location...

1. ... with enough space. This is, plan for at least 4 or 5 times the size of
the input files.

2. ... accessible by worker nodes. If you're using a single server, this is not
really an issue. However, if you plan on deploying MiGA in a cluster
infrastructure, make sure your project is reachable by worker nodes.

3. ... with fast access. It's not a great idea to set up projects in remote
drives with large latency. In some cases there no way around this, for example
when that's the only available option in your cluster infrastructure, but try
to avoid this as much as possible.

Now that you know where to create your project, go ahead and run:

```bash
miga create_project -P /path/to/project1 -t type-of-project
```

Where `/path/to/project1` is the path to where the project should be created.
You don't need to create the folder in advance, MiGA will take care. See the
next section to help you decide what `type-of-project` to use. There are some
other options that are not mandatory, but will make your project richer. Take a
look at `miga create_project -h`.

#### Project types

Projects can be set for different purposes, so we've divided them into "types".
There are four of them, depending on the types of datasets to be processed (see
[Dataset types](#dataset-types)):

1. **mixed**: A generic project with any supported type of datasets.

2. **metagenomes**: A project containing only metagenomic datasets. This
includes either (or both) metagenomes and viromes.

3. **genomes**: A project containing only single-organism datasets. This
includes any of the single-organism types: genome, scgenome, and/or popgenome.

4. **clade**: Same as "genomes", but all the datasets are expected to be from
the same species. This type of project performs additional analyses that expect
a very dense ANI matrix, so all genomes in it are expected to have AAI > 90%.

### Creating datasets

Once your project is ready, you can start populating it with datasets and data.
While it's possible to create empty datasets using `miga create_dataset`, the
preferred method is to first add data and then use the data to create the
datasets in batch. For example, lets assume you have a collection of paired-end
raw reads from several datasets. The first step is to format the filenames
properly. For each one of your datasets, pick a name that conforms the
[MiGA names](#miga-names) restrictions (we'll call it "ds1") and rename your
reads to `/path/to/project1/data/01.raw_reads/ds1.1.fastq` for the first
sister and `/path/to/project1/data/01.raw_reads/ds1.2.fastq` for the second
sister. Also, add the date into `/path/to/project1/data/01.raw_reads/ds1.done`.
Check what are the [expected result files](#expected-result-files) below if you
want to start at any other point in the pipeline. Once you have renamed (or
copied) the files inside the project folder, run:

```bash
miga find_datasets -P /path/to/project1 -a -r -t type-of-dataset
```

The `-a` flag tells MiGA that you want to add the datasets (not just find them);
the `-r` flag tells MiGA that your datasets are to be treated as "reference"
datasets (see [Non-reference datasets](#non-reference-datasets) below); and the
`-t` option tells MiGA what type of datasets you're adding (see
[Dataset types](#dataset-types) below). If you have a mixture of dataset types,
process one at a time. This is, perform this step for each dataset type. Don't
worry about the datasets that are already registered, those will be ignored by
the `find_datasets` task and will remain unchanged.

#### Expected result files

For brevity, we'll assume that you're inside `/path/to/project1/data`; *i.e.*,
in the `data` directory of your project. We'll also assume that you're naming
your dataset **ds1**, but you can change this by anything following the
[MiGA names](#miga-names) restrictions. Now, these are the "input" points that
you can use in MiGA:

1. **Paired-end raw reads**: The expected files are `01.raw_reads/ds1.1.fastq`
and `01.raw_reads/ds1.2.fastq`, each including a sister end. The reads must be
in the same order in both files (MiGA won't check). You can also use gzipped
files instead.

2. **Single-end raw reads**: The expected file is `01.raw_reads/ds1.1.fastq`.
You can also use a gzipped file instead.

3. **Paired-end trimmed reads**: These are assumed to be quality-controlled
reads in FastA format, with both ends passing the quality filters. The minimum
expected file is `04.trimmed_fasta/ds1.CoupledReads.fa`, which contains the
reads interposed. You can also pass (in addition) the reads that past the
quality check without the sister as a gzipped FastA at
`04.trimmed_fasta/ds1.SingleReads.fa.gz`.

4. **Single-end trimmed reads**: Similar to the option above, only
quality-checked reads are expected here. The expected file is
`04.trimmed_fasta/ds1.SingleReads.fa`.

5. **Assembled fragments**: This can be any assembly result, including complete
genomes. The expected file is `05.assembly/ds1.LargeContigs.fna`, containing
only contigs longer than 500bp. You can also provide the complete assembly
(without length-filtering) at `05.assembly/ds1.AllContigs.fna`.

6. **Predicted genes/proteins**: This is the total collection of predicted genes
and proteins. The expected files are `06.cds/ds1.fna`, containing genes, and
`06.cds/ds1.faa`, containing proteins. You can also provide the locations of
said genes in the genome in gzipped GFF v2 (`06.cds/ds1.gff2.gz`), gzipped
GFF v3 (`06.cds/ds1.gff3.gz`), or gzipped tabular (`06.cds/ds1.tab.gz`).

**IMPORTANT**: In all cases, an additional `ds1.done` file MUST be created in
the same folder. This is meant to prevent MiGA from mistakenly adding files as
results before they're done being processed or transferred. This file must
contain the current [date in MiGA format](#date-in-miga-format). Here's a quick
code snippet to add the `.done` file for all the input files in `01.raw_reads`
(you can adapt this accordingly to any of the other options):

```bash
cd /path/to/project1/data/01.raw_reads
for i in *.1.fastq ; do
   date "+%Y-%m-%d %H:%M:%S %z" > $(basename $i .1.fastq).done
done
```

#### Dataset types

This is how you tell MiGA what kind of data you have in your datasets. Lets see
the definitions:

1. **genome**: The genome from an isolate.
2. **metagenome**: A metagenome (excluding viromes).
3. **virome**: A viral metagenome.
4. **scgenome**: A genome from a single cell.
5. **popgenome**: The genome of a population (including microdiversity).

#### Non-reference datasets


#### Creating a RefSeq project

If you've reached this point, you are now ready to create a large functional
project. If you want to continue using this documentation on real data but
don't have any of your own handy (or if you want to use RefSeq data), this
is a quick tutoral on how to create a functional MiGA project using ALL of
NCBI's Prokaryotic RefSeq data.

**Step 1: Create the project**. That's simple, just `cd` to the directory you
want to use, and execute `miga create_project -P MiGA_RefSeq -t genomes`.

**Step 2: Download the data**. Just `cd MiGA_RefSeq`, and execute this code:

```bash
wget -O reference_genomes.txt 'http://www.ncbi.nlm.nih.gov/genomes/Genome2BE/genome2srv.cgi?action=refgenomes&amp;download=on&amp;type=reference'
grep -v '^#' reference_genomes.txt \
   | awk -F'\t' '{gsub(/[^A-Za-z0-9]/,"_",$3)} {print "miga download_dataset -P . -D "$3" -I "$4" -U ncbi --db nuccore -t genome -v # "$3""}' \
   | while read ln ; do
      sp=$(echo $ln | perl -pe 's/.*# //')
      if [[ ! -n $(miga list_datasets -P . -D $sp) ]] ; then
	 echo $ln
	 $ln
      fi
   done
```

And that's it. The first line will download the most current list of genomes
included in NCBI's Prokaryotic RefSeq, and the rest will repeatedly execute the
`download_dataset` task, that automatically fetches the data (even the genome's
taxonomy!). Note that the code above checks first if a dataset already exists,
so if you want to update an existing MiGA_RefSeq project, simply repeat step 2
and only missing genomes will be fetched.

Note that running time for the above code may vary depending on the network and
the size of RefSeq, but I was able to create a complete project with 122 genomes
in under 10 minutes.

**Alternative step 2: downloading all representatives**. If you want a larger
and more comprehensive collection, and not just the reference genomes, you can
download all of the representative genomes in the prokaryotic RefSeq with this
alternative code:

```bash
wget -O representative_genomes.txt 'http://www.ncbi.nlm.nih.gov/genomes/Genome2BE/genome2srv.cgi?action=refgenomes&amp;download=on'
grep -v '^#' representative_genomes.txt \
   | awk -F'\t' '{gsub(/[^A-Za-z0-9]/,"_",$3)} $4{print "miga download_dataset -P . -D "$3" -I "$4" -U ncbi --db nuccore -t genome -v # "$3""}' \
   | while read ln ; do
      sp=$(echo $ln | perl -pe 's/.*# //')
      if [[ ! -n $(miga list_datasets -P . -D $sp) ]] ; then
	 echo $ln
	 $ln
      fi
   done
```

This is a much larger set (1,246), hence it'll take much more time. I finished
downloading the whole thing in about one and a half hours.


Launching daemons
-----------------

### Configuring daemons


### Understating the MiGA configuration file


### Arbitrary configuration scripts


### Fixing system calls with aliases

In some cases, we might not have the same executable names as MiGA expects, or
we might have broken modules in our cluster that can be easily fixed with an
`alias`. In these cases, you can use
[arbitrary configuration scripts](#arbitrary-configuration-scripts) to generate
one or more `alias`. Importantly, MiGA daemons work with non-interactive shells,
which means you likely need to explicitly allow for alias extensions, for
example:

```bash
# Allow alias expansions in non-interactive shells
shopt -s expand_aliases

# Call FastQC with the environmental Perl,
# not the built-in /usr/bin/perl:
alias fastqc="perl $(which fastqc)"

# Use the standard name for RAxML (pthreads)
# instead of the one my sys-admin decided to use:
alias raxmlHPC-PTHREADS=RAxML_pthreads
```

The examples above illustrate how to use `alias` to fix broken packages or to
make Software with non-standard names reachable.

**Known caveats to this solution:** This solution CANNOT BE USED in the few
cases in which a whole package is expected based on a single executable. For
example, adding the enveomics scripts to your `PATH` is far easier than creating
an `alias` for each script. Also, MiGA expects to find the model, the activation
key, and the scripts of MetaGeneMark in the same folder of the `gmhmmp` binary,
so setting an`alias` may prevent MiGA from finding these ancillary files.


Cluster infrastructure
----------------------


### Loading optional modules


See also [Fixing system calls with aliases](#fixing-system-calls-with-aliases).


Miscellaneous
-------------


Authors
-------

Developed and maintained by [Luis M. Rodriguez-R][lrr].


License
-------

See [LICENSE](LICENSE).

[lrr]: http://lmrodriguezr.github.io/
