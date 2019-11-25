# Get taxonomy of genomes

This tutoral guides you through comparing your genomes,
Metagenome-Assembled Genomes (MAGs), or Single-Cell Amplified
Genomes (SAGs) against a reference project for taxonomy.
A reference project has to be a separate MiGA project with
a database of your choice. 

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
# Example 1:
# Add datasets with default settings
miga add -P . -t popgenome -i assembly path/to/mags/*.fasta

# Example 2:
# Same thing but forcing MyTaxa Scan and Distances not to run.
# These are both long steps not required for taxonomy.
# To do this, add the metadata flag when creating each dataset
miga add -P . -t popgenome -i assembly path/to/mags/*.fasta \
  -m run_mytaxa_scan=false,run_distances=false
```

You can get more information on metadata flags
[here](../part5/metadata.md#dataset),
or read more about these steps: [MyTaxa Scan](../part5/workflow.md#mytaxa-scan)
and [distances](../part5/workflow.md#distances).

# 4. Launch daemon

See [Launching Daemons](../part4/daemons.md) for more details. The most common
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
