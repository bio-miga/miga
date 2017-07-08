# RefSeq in MiGA

In this tutorial, we will create a genomes project including all the
representative genomes available in RefSeq. For this tutorial you'll need some
*nix utilities, including `curl`, `tail`, `cut`, `awk`, `gzip`, and `perl`.

## 0. Initialize the project

```bash
miga create_project -P RefSeq -t genomes
cd RefSeq
```

## 1. Download publicly available genomes

**Re-running and updating**: If the following code fails at any point, for
example due to a network interruption, you can simply re-run it, and it will
take it from where it failed. If it fails in the last command
(`miga download_dataset`), you can simply re-run that one command (not the whole
thing). Also, you can simply re-run the whole code below in the future if you
want to update your project with more recently released genomes.

```bash
# Get the list of genomes:
NCBI_SCRIPT="https://www.ncbi.nlm.nih.gov/genomes/Genome2BE/genome2srv.cgi"
NCBI_PARAMS="action=refgenomes&download=on"
curl -o rep_genomes.tsv "$NCBI_SCRIPT?$NCBI_PARAMS"

# Format the list for MiGA:
( echo -e "dataset\tids"
tail -n +2 rep_genomes.tsv | cut -f 3,4 \
  | awk 'BEGIN { FS="\t"; OFS="\t" } \
    { gsub(/[^A-Za-z0-9]/,"_",$1) } \
    $2 { print $0 }'
  ) \
  > rep_genomes_miga.tsv

# Download remote entries:
miga get -P . --file rep_genomes_miga.tsv \
  --universe ncbi --db nuccore --ignore-dup --verbose -t genome
```

## 2. Launch the daemon

Now that your data is ready, you can fire up the daemon to start processing the
data. For additional details, see [launching daemons](daemons.md):

```bash
miga daemon start -P .
```
