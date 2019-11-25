# Preprocess input genomes or metagenomes

This workflow automates the preprocessing of your genomic or metagenomic
datasets.

To execute the workflow, run:

```bash
miga preproc_wf -o my_project -i raw_reads_single path/to/reads/*.fastq
```

Supported inputs include:

* *raw_reads_single:* Single raw reads in a single FastQ file
* *raw_reads_paired:* Paired raw reads in two FastQ files
* *trimmed_reads_single:* Single trimmed reads in a single FastA file
* *trimmed_reads_paired:* Paired trimmed reads in two FastA files
* *trimmed_reads_interleaved:* Paired trimmed reads in a single FastA file
* *assembly:* Assembled contigs or scaffolds in FastA format


For additional options, run:

```bash
miga preproc_wf -h
```

## Expected output

Once your run is complete, you may expect the [standard summaries](summaries.md)
for `cds`, `assembly`, `essential_genes`, and `ssu`. In addition, all the
intermediate files are preserved, including assemblies, predicted genes, and
detected essential and ribosomal genes.

