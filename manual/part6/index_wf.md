# Generate distance indexing of input genomes

This workflow automates the indexing of your genomic collection.

To execute the workflow, run:

```bash
miga index_wf -o my_project path/to/genomes/*.fasta
```

For additional options, run:

```bash
miga index_wf -h
```

## Expected output

Once your run is complete, you may expect the [standard summaries](summaries.md)
for `cds`, `assembly`, `essential_genes`, and `ssu`. In addition, all the
intermediate files are preserved, including assemblies, predicted genes, and
detected essential and ribosomal genes. Importantly, all-vs-all comparisons are
generated using Average Amino Acid Identity (AAI) and Average Nucleotide
Identity (ANI), making this a queriable project.

## Indexing publicly available genomes

It is also possible to use this workflow on genomes publicly available in NCBI.
This enables taxonomic analysis, such as using this indexed project as a
reference database for the [classification workflow](classify_wf.md).

For example, to download and index all the genomes from the species
**Xanthomonas vesicatoria** using Diamond for AAI and FastANI for ANI
estimation (`--fast` flag), run:

```bash
miga index_wf -o X_vesicatoria \
  -T 'Xanthomonas vesicatoria' --project-type clade --fast -v
```

