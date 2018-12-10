# Build a clade collection

In this tutorial, we will create a clade project including all the genomes
available for a species in RefSeq as well as any additional genomes you may have
using MiGA alone. If you want to explore a more manual approach using `bash`,
see the [Build a clade collection using BASH example](deploy-clade-bash.md).
We will use *Escherichia coli* as the target species, but you can use any
species (or any taxon) you want.

## 0. Initialize the project

```bash
miga new -P E_coli -t clade
cd E_coli
```

## 1. Download publicly available genomes

There are different stages of completeness defined in the NCBI Genome database,
and you may want to include only some cases depending on you analysis. The
stages (from higher to lower quality) are:

1. *Complete*: Genomes including all replicons in the organism(s) sequenced.
2. *Chromosome*: Genomes with complete chromosome (but missing other replicons).
3. *Scaffold*: Draft genomes with scaffold status.
4. *Contig*: Draft genomes with contig status.

In this example, we'll skip the draft genomes. However, if you want all of them,
simply use the `--all` option of `miga ncbi_get`.

**Re-running and updating**: If the following code fails at any point, for
example due to a network interruption, you can simply re-run it, and it will
take it from where it failed.

```bash
miga ncbi_get -T "Escherichia coli" -P . --complete --chromosome -v
```

Note that you can change the value of `-T` from `"Escherichia coli"` to any
other species name, or even taxa of any rank such as genus or family.

It is strongly recommended to use an
[NCBI API Key](https://ncbiinsights.ncbi.nlm.nih.gov/2017/11/02/new-api-keys-for-the-e-utilities/)
to increase the number of allowed requests. Once you obtain one, you can pass it
as an argument:

```bash
miga ncbi_get -T "Escherichia coli" -P . --complete --chromosome --api-key ABCD123 -v
```

Or you can set it globally as an environmental variable before running `miga`:

```bash
export NCBI_API_KEY=ABCD123
```

## 2. Add your own genomes

If you have any unreleased genomes, you can simply add them to the same project
to be processed together with those publicly available. You can initialize
datasets at different points, see [input data](../part2/input.md). For the
purposes of this tutorial, we'll assume that you have raw coupled reads from two
sequencing lanes (1 and 2) in Gzipped FastQ files:

```bash
# Unzip and/or concatenate input files
# this is not necessary if your files are ready to use:
gzip -d -c ~/some/file/d1_ACTG_L[12]_R1.fastq.gz > /tmp/sister-1.fastq
gzip -d -c ~/some/file/d1_ACTG_L[12]_R2.fastq.gz > /tmp/sister-2.fastq

# Register the dataset
# change the dataset name MyDataset to whichever name you want:
miga add -P . -D MyDataset -t genome \
      --trimmed-fasta-coupled /tmp/sister-1.fastq,/tmp/sister-2.fastq
```

## 3. Launch the daemon

Now that your data is ready, you can fire up the daemon to start processing the
data. For additional details, see [launching daemons](daemons.md):

```bash
miga daemon start -P .
```

