# RefSeq in MiGA

In this tutorial, we will create a genomes project including all the
representative genomes available in RefSeq using MiGA alone. If you want
to explore a more manual approach using `bash`, see the
[RefSeq in MiGA using BASH example](deploy-refseq-bash).

## 0. Initialize the project

```bash
miga new -P RefSeq -t genomes
cd RefSeq
```

## 1. Download publicly available genomes

**Re-running and updating**: If the following code fails at any point, for
example due to a network interruption, you can simply re-run it, and it will
take it from where it failed.

```bash
miga ncbi_get -P . --reference -v
```

## 2. Launch the daemon

Now that your data is ready, you can fire up the daemon to start processing the
data. For additional details, see [launching daemons](daemons):

```bash
miga daemon start -P .
```
