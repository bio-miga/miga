# Dereplicate a collection of input genomes

This workflow automates the dereplication of your collection of genomes,
Metagenome-Assembled Genomes (MAGs), or Single-Cell Amplified Genomes (SAGs).

To execute the workflow, run:

```bash
miga derep_wf -o my_project path/to/mags/*.fasta
```

For additional options, run:

```bash
miga derep_wf -h
```

Importantly, the dereplication can be performed on ANI (default) or AAI (passing
the `--aai` flag) at a given threshold (by default 95%) that can be modified
with the flag `--threshold`. Finally, the representative genomes can be selected
to reflect the highest genome quality (default) or to be the most "central"
genome in the clade in ANI or AAI space (passing the `--medoids` flag).

## Expected output

Once your run is complete, you may expect the
[standard summaries](summaries.md) for `cds`, `assembly`, and `essential_genes`,
as well as a table (`genomospecies.tsv`) with three columns: (1) a clade name,
(2) the name of the representative genome, and (3) the names of all the members
in the clade separated by commas.
Additionally you can expect the subdirectory `representatives` including
assemblies (FastA files, nucleotides) of all representative genomes.
This is the dereplicated set of genomes.

