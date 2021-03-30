# Installing requirements using Conda

You can use [conda](https://conda.io/) to install most of the Software required
by MiGA.
If you don't have Conda, you can follow the
[Installation instructions](https://conda.io/projects/conda/en/latest/user-guide/install/index.html).

## Live notebook

If you prefer to see code in action, the full installation process
with conda is available as a
[Notebook in Google Colab](https://colab.research.google.com/drive/1d8ClPe8dQOPp2eviQh6bX3inI84USzE4).

## Note for macOS users

> In general, it is recommended to use [Homebrew](brew.md) to install MiGA if
> possible. The MiGA installation in macOS using conda is known to be fragile
> and extremely time-consuming (it could take upwards of 20 minutes just solving
> the environment).

## Packages

Now, install all the required packages using conda:

```bash
# Install prerequisites
curl -Lso miga.yml \
  "https://raw.githubusercontent.com/bio-miga/miga/main/conda.yml"
conda env create -f miga.yml
rm miga.yml

# Tell MiGA to activate the proper conda environment
echo 'eval "$(conda shell.bash hook)" && conda activate miga' > ~/.miga_modules

# Activate the environment
. ~/.miga_modules
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

