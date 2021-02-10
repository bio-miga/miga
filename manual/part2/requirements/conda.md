# Installing requirements using Conda

You can use [conda](https://conda.io/) to install most of the Software required
by MiGA.
If you don't have Conda, you can follow the
[Installation instructions](https://conda.io/projects/conda/en/latest/user-guide/install/index.html).

## Live notebook

If you prefer to see code in action, the full installation process
with conda is available as a
[Notebook in Google Collab](https://colab.research.google.com/drive/1ybCCPbbZtJ41HC_1yNYed8Yf-q9CDY5a).

## Note for MacOS users

> The bioconda fastani recipe currently depends on packages that force
> downgrading other important packages (including R). This can cause some
> issues, and we're currently recommending the use of [Homebrew](brew.md)
> whenever possible. If this is not an option for you, a good alternative might
> be to install FastANI from source instead of using conda. Finally, you could
> use the instructions below, if the risk of employing old libraries outweights
> the burden of installation.

## Essentials

Now that you have Conda, activate it. If you want to create a separate clean
environment (optional) you can simply execute:

```bash
conda create -y -n miga python=3.7
conda activate miga
```

It's strongly recommended to activate conda in the `~/.miga_modules`:

```bash
# Tell MiGA to activate the proper conda environment:
echo 'eval "$(conda shell.bash hook)" && conda activate miga' > ~/.miga_modules
```

Next, install the requirements:

```bash
conda install -y -c conda-forge r-base r
conda install -y --strict-channel-priority -c conda-forge ruby
conda install -y sqlite openjdk
conda install -y -c conda-forge -c bioconda -c faircloth-lab \
  scythe blast hmmer bedtools prodigal idba mcl barrnap \
  fastqc diamond krona fastani
```

## SolexaQA

There is a version of SolexaQA in conda, but the recipe forced downgrading R and
is only available for Linux. Therefore, a safer option is to obtain the
precompiled binaries directly from the developers
[here](https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA++_v3.1.7.1.zip).

Unzip that file, and locate the appropriate binary in a folder listed in your
`$PATH`.

## R packages

The full list of R packages is automatically installed by MiGA. However, we
will install one package here to make sure everything is properly initialized.

```bash
Rscript -e "install.packages('ape', repos = 'http://cran.rstudio.com/')"
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).
