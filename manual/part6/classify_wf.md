# Classify input genomes against a reference database

This workflow automates the comparison of your genomes,
Metagenome-Assembled Genomes (MAGs), or Single-Cell Amplified
Genomes (SAGs) against a reference project for taxonomy.

A reference project has to be a separate MiGA project with
a database of your choice, taxonomically annotated, and fully indexed.
If you want to use the pre-processed database provided by MiGA Online, run:

```bash
miga download
```

To execute the workflow, run:

```bash
miga classify_wf -o my_project path/to/mags/*.fasta
```

For additional options, run:

```bash
miga classify_wf -h
```

## Expected output

Once your run is complete, you may expect the [standard summaries](summaries.md)
for `cds`, `assembly`, `essential_genes`, and `taxonomy`,
as well as a summary classification table (`classification.tsv`)
with two columns: (1) the genome name, and (2) the space-delimited
classification of the genome with taxon names prefixed by the rank code and a
colon. Something like:

```
NZ_CP010409_1	d:Bacteria p:Proteobacteria c:Gammaproteobacteria o:Xanthomonadales f:Xanthomonadaceae g:Xanthomonas s:Xanthomonas_sacchari
NZ_CP016878_1	d:Bacteria p:Proteobacteria c:Gammaproteobacteria o:Xanthomonadales f:Xanthomonadaceae g:Xanthomonas s:Xanthomonas_hortoru
[...]
```

