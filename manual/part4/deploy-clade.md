# Build a clade collection

In this tutorial, we will create a clade project including all the genomes
available for a species in RefSeq as well as any additional genomes you may
have. We will use *Escherichia coli* as the target species, but you can use
any species you want. For this tutorial you'll need some *nix utilities,
including `curl`, `tail`, `cut`, `awk`, `gzip`, and `perl`.

## 0. Initialize the project

```bash
miga create_project -P E_coli -t clade
cd E_coli
```

## 1. Download publicly available genomes

There two options here: (A) use complete genomes, or (B) use draft genomes. You
can use either depending on your needs, or both if you want to get as much data
as possible regardless of completeness. These two options are non-redundant, so
you can combine them if you want.

**Re-running and updating**: If the following code fails at any point, for
example due to a network interruption, you can simply re-run it, and it will
take it from where it failed. If it fails in the last command
(`miga download_dataset`), you can simply re-run that one command (not the whole
thing). Also, you can simply re-run the whole code below in the future if you
want to update your project with more recently released genomes.

### 1a. Download complete genomes

The first option is to download complete genomes (and/or chromosome-level) from
NCBI, including NCBI taxonomy:

```bash
# Specify the organism (use %20 instead of spaces):
ORGN="Escherichia%20coli"

# Set level of completeness:
STATUS="50|40" # <- Complete or Chromosome
# STATUS="50" # <- Only complete
# STATUS="40" # <- Only chromosome

# Get the list of genomes:
NCBI_SCRIPT="https://www.ncbi.nlm.nih.gov/genomes/Genome2BE/genome2srv.cgi"
NCBI_PARAMS="action=download&report=proks&group=--%20All%20Prokaryotes%20--"
NCBI_PARAMS="$NCBI_PARAMS&subgroup=--%20All%20Prokaryotes%20--"
NCBI_PARAMS="$NCBI_PARAMS&orgn=$ORGN\\[orgn\\]&status=$STATUS"
curl -o ref_genomes.tsv "$NCBI_SCRIPT?$NCBI_PARAMS"

# Format the list for MiGA:
( echo -e "dataset\tids" ;
tail -n +2 ref_genomes.tsv | cut -f 1,11 \
  | awk 'BEGIN{FS="\t"; OFS="\t"} \
    { gsub(/[^A-Za-z0-9]/,"_",$1); gsub(/[^:;]*:/,"",$2) } \
    { gsub(/\/[^\/;]*/,"",$2) } {print $0}' \
  | tr ";" "," | perl -pe 's/\t([^,\.]+)/_\1\t\1/') \
  > ref_genomes_miga.tsv

# Download remote entries:
miga download_dataset -P . --file ref_genomes_miga.tsv \
  --universe ncbi --db nuccore --ignore-dup --verbose -t genome
```

### 1b. Download draft genomes

Option B is to download draft genomes from the assembly database in NCBI.
Unfortunately, this task doesn't link the entries with NCBI taxonomy because
EUtils currently doesn't support WGS assemblies:

```bash
# Specify the organism (use %20 instead of spaces):
ORGN="Escherichia%20coli"

# Set level of completeness:
STATUS="30|20" # <- Scaffold or contig
# STATUS="30" # <- Only scaffold
# STATUS="20" # <- Only contig

# Get the list of genomes:
NCBI_SCRIPT="https://www.ncbi.nlm.nih.gov/genomes/Genome2BE/genome2srv.cgi"
NCBI_PARAMS="action=download&report=proks&group=--%20All%20Prokaryotes%20--"
NCBI_PARAMS="$NCBI_PARAMS&subgroup=--%20All%20Prokaryotes%20--"
NCBI_PARAMS="$NCBI_PARAMS&orgn=$ORGN\\[orgn\\]&status=$STATUS"
curl -o draft_genomes.tsv "$NCBI_SCRIPT?$NCBI_PARAMS"

# Format the list for MiGA:
( echo -e "dataset\tcomments\tids" ;
cat draft_genomes.tsv | tail -n +2 | cut -f 1,8,20 \
  | awk 'BEGIN{FS="\t"; OFS="\t"} \
    { gsub(/[^A-Za-z0-9]/,"_",$1); gsub(/[^:;]*:/,"",$2) } \
    { gsub(/\/[^\/;]*/,"",$2) } {print $0}' \
  | tr ";" "," | perl -pe 's/\t([^,\.]+)/_\1\tAssembly: \1/' ) \
  | perl -pe 's/\/([^\/\n\r]+)[\n\r]*$/\/\1\/\1_genomic.fna.gz\n/' \
  > draft_genomes_miga.tsv

# Download remote entries:
miga download_dataset -P . --file draft_genomes_miga.tsv \
  --universe web --db assembly_gz --ignore-dup --verbose -t genome
```

## 2. Add your own genomes

If you have any unreleased genomes, you can simply add them to the same project
to be processed together with those publicly available. You can initialize
datasets at different points, see [input data](../part2/input.md). For the
purposes of this tutorial, we'll assume that you have raw coupled reads from two
sequencing lanes (1 and 2) in Gzipped FastQ:

```bash
# Set the name of the dataset (only alphanumerics and underscores):
DS=dataset1

# Copy, cat, or move input files. Something similar to:
gzip -d -c ~/some/file/d1_ACTG_L[12]_R1.fastq.gz > data/01.raw_reads/$DS.1.fastq
gzip -d -c ~/some/file/d1_ACTG_L[12]_R2.fastq.gz > data/01.raw_reads/$DS.2.fastq

# Tell MiGA your transfer is complete
miga date > data/01.raw_reads/$DS.done

# Register the dataset:
miga create_dataset -P . -D $DS -t genome
```

## 3. Launch the daemon

Now that your data is ready, you can fire up the daemon to start processing the
data. For additional details, see [launching daemons](daemons.md):

```bash
miga daemon start -P .
```

