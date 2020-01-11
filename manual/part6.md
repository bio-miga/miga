# Part VI: CLI Workflows

CLI Workflows automate common tasks in MiGA.
Currently implemented workflows include:

1. [Quality](part6/quality_wf.md)
2. [Dereplicate](part6/derep_wf.md)
3. [Classify](part6/classify_wf.md)
4. [Preprocess](part6/preproc_wf.md)
5. [Index](part6/index_wf.md)

## Using multiple workflows

It is possible to concatenate workflows in the same project.
First, run the first workflow as described in the documentation.
For example:

```bash
miga quality_wf -o my_project /path/to/genomes/*.fna
```

Next, execute any additional steps *without* specifying the input files,
and using the same output directory. For example:

```bash
miga classify_wf -o my_project
miga rerep_wf -o my_project
```

In the examples above, input genomes will be processed to evaluate quality, next
they'll be classified, and finally they'll be dereplicated.

