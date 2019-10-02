# Installing requirements using Conda

You can use [conda](https://conda.io/) to install most of the Software required
by MiGA.
If you don't have Conda, you can follow the
[Installation instructions](https://conda.io/projects/conda/en/latest/user-guide/install/index.html).

## Essentials

Now that you have Conda, activate it. If you want to create a separate clean
environment (optional) you can simply execute:

```bash
conda create -y -n miga
source activate miga
```

It's strongly recommended to activate conda in the `~/.miga_modules`:

```bash
# Tell MiGA to always activate conda:
echo 'eval "$(conda shell.bash hook)"' >> ~/.miga_modules
# Tell MiGA to activate the proper conda environment:
echo 'source activate miga' >> ~/.miga_modules
```

Next, install the requirements:

```bash
conda install -y -c anaconda sqlite r-base
conda install -y -c conda-forge ruby
conda install -y -c conda-forge -c bioconda -c faircloth-lab \
  scythe blast hmmer bedtools prodigal idba mcl barrnap \
  fastqc diamond krona fastani solexaqa
```

**Note for MacOS users:**
> The current recipe for SolexaQA++ only supports
> Linux.
> However, a precompiled SolexaQA++ binary for MacOS can be obtained directly
> from the developers
> [here](https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA++_v3.1.7.1.zip).
> Simply remove `solexaqa` from the list above, and download that binary
> manually.

**Note for Linux users:**
> In some environments you'll also need gfortran installed in order to compile
> some R packages: `conda install gfortran_linux-64`

## R packages

The full list of R packages are automatically installed by MiGA. However, we
will install one package here to make sure everything is properly initialized.

```bash
R
install.packages('enveomics.R', repos = 'http://cran.rstudio.com/')
q('no')
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).
