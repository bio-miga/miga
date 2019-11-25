# Evaluate the quality of input genomes

This workflow automates the evaluation of quality statistics on your genomes,
Metagenome-Assembled Genomes (MAGs), or Single-Cell Amplified Genomes (SAGs).

To execute the workflow, run:

```bash
miga quality_wf -o my_project path/to/mags/*.fasta
```

For additional options, run:

```bash
miga quality_wf -h
```

## Expected output

Once your run is complete, you may expect the
[standard summaries](summaries.md) for `cds`, `assembly`, `essential_genes`, and
`ssu`. In addition, if you pass the option `--mytaxa-scan`, you can expect the
subdirectory `mytaxa_scan` including PDF reports for each input genome.

