# RefSeq in MiGA

In this tutorial, we will create a genomes project including all the
representative genomes available in RefSeq using MiGA alone. If you want
to explore a more manual approach using `bash`, see the
[RefSeq in MiGA using BASH example](deploy-refseq-bash.md).

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
miga ncbi_get -P . --reference -v -T Archaea
```

Of course, you can repeat for `-T Bacteria` to get all prokaryotic genomes.

It is strongly recommended to use an
[NCBI API Key](https://ncbiinsights.ncbi.nlm.nih.gov/2017/11/02/new-api-keys-for-the-e-utilities/)
to increase the number of allowed requests. Once you obtain one, you can pass it
as an argument:

```bash
miga ncbi_get -P . --reference --api-key ABCD123 -v -T Archaea
```

Or you can set it globally as an environmental variable before running `miga`:

```bash
export NCBI_API_KEY=ABCD123
```

## 2. Launch the daemon

Now that your data is ready, you can fire up the daemon to start processing the
data. For additional details, see [launching daemons](daemons.md):

```bash
miga daemon start -P .
```
