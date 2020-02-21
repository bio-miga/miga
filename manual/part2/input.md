# Input data

MiGA datasets can be created from three different points:
[Raw reads](#raw-reads), [Trimmed reads](#trimmed-reads), and
[Assemblies](#assemblies).

The input files can be added through the [CLI](../part3/cli.md) using
`miga add` or any of the available [workflows](../part6.md).
Files can also be added through the [Web](../part3/web.md) interface.

## Raw reads

- **Description**:
Raw (unprocessed) sequencing reads.
MiGA can handle different sequencing technologies,
but it has been optimized for short reads.
- **Format**: FastQ, optionally gzipped (with .gz extension)
- **Workflow step**: [Raw reads](../part5/workflow.md#raw_reads)

## Trimmed reads

- **Description**:
Sequencing reads already processed to remove low quality or other artifacts.
MiGA can handle different sequencing technologies,
but it has been optimized for short reads.
- **Format**: FastA, optionally gzipped (with .gz extension)
- **Workflow step**: [Trimmed FastA](../part5/workflow.md#trimmed_fasta)

## Assemblies

- **Description**:
Assembled contigs/scaffolds.
Ideally, but not necessarily, sequences longer than 1 Kbp.
- **Format**: FastA, optionally gzipped (with .gz extension)
- **Workflow step**: [Assembly](../part5/workflow.md#assembly)

