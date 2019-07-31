# Get taxonomy of genomes

*TODO: EXPLAIN THE PROBLEM SHORTLY HERE*

## 1. Create an empty MiGA project

First, you'll have to create a project. We'll call it `MAGs`.

```bash
miga new -P MAGs -t genomes
cd MAGs
```

## 2. Specify a reference project in metadata

Next, let MiGA know where the reference database is located.

```bash
miga edit -P . -m "ref_project=/path/to/reference_project"
```

## 3. Create a dataset for the MiGA project for each genome

Add the genomes to your project. In this example we are working with
Metagenome-Assembled Genomes (MAGs), which we specify with `-t popgenome`.
If you have Single-Cell Amplified Genomes (SAGs) you can use instead
`-t scgenome`. If you're working with genomes from isolates, use
`-t genome`.

```bash
# Example 1: mag_1.fasta, mag_2.fasta
miga add -P . -D mag_1_name -t popgenome --assembly "path/to/mag_1.fasta"
miga add -P . -D mag_2_name -t popgenome --assembly "path/to/mag_2.fasta"

# Example 2: same thing but forcing MyTaxa Scan and Distances not to run
# These are both long steps not required for taxonomy
# To do this, add the metadata flag when creating each dataset
# https://manual.microbial-genomes.org/part5/metadata#datasets
# https://manual.microbial-genomes.org/part5/workflow#mytaxa-scan
# https://manual.microbial-genomes.org/part5/workflow#distances
miga add -P . -D mag_3_name -t popgenome --assembly "path/to/mag_3.fasta" -m run_mytaxa_scan=false,run_distances=false
miga add -P . -D mag_4_name -t popgenome --assembly "path/to/mag_4.fasta" -m run_mytaxa_scan=false,run_distances=false

# Example 3: paths to genomes in file Paths.txt
# For each genome, add a dataset
for path in $(cat path/to/Paths.txt); do
  # Example name: mag file name without extension ".fasta" and with underscores only.
  name=$(basename "$path" .fasta | sed 's/[^A-Za-z0-9]/_/g')
  miga add -P . -D "$name" -t popgenome --assembly "$path"
done
```

# 4. Launch daemon

See [Launching Daemons](part4/daemons.md) for more details. The most common
case would be:

```bash
miga daemon start -P .
```

# 5. Display information about the MiGA project at any time

```bash
# Check for correct number of datasets and reference project
miga about -P .

# Display information about each dataset at any time
miga ls -P . -i

# See the advance of the jobs
miga ls -P . -p
```

# 6. List taxonomy for all datasets after the project finishes running

```bash
miga ls -P . -m tax
```
