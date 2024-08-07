# Live notebook

If you prefer to see code in action, the full installation process
with homebrew is available as a
[Notebook in Google Colab](https://colab.research.google.com/gist/lmrodriguezr/4af3b345067e862dc7903e4c78ad40ac).

# Installing requirements using Homebrew

You can use [Homebrew](https://brew.sh/) to install most of the software
required by MiGA.
If you don't have Homebrew, execute (and follow the instructions):

```bash
/bin/bash -c "$(curl -fsSL \
  https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## A recent Ruby

It's possible you already have a recent version of ruby (2.3+).
To check which version you have, simply run: `ruby -v`.
If your version of Ruby is older than 2.3, you can install a recent
version using:

```bash
brew install libyaml rbenv
rbenv install 3.3.0
rbenv global 3.3.0
```

## Packages

Now that you have Homebrew, execute:

```bash
brew tap brewsci/bio
# In Linux, replace 'temurin' with 'openjdk'
brew install \
    r sqlite3 python numpy pigz temurin \
    blast hmmer bedtools prodigal gmp idba mcl krona \
    barrnap diamond fastani faqcs brewsci/bio/falco seqtk fastp trnascan
```

Additionally, recent changes in `pip` might break some installations, and
as such we recommend pre-installing python packages in a brew environment:

```bash
pip install --break-system-packages pyhmmer pyrodigal
```

We also recommend installing the `sqlite3` gem beforehand using the brew
libraries, to avoid headaches down the road (but this is optional):

```bash
gem install sqlite3 -- --with-sqlite3-dir="$(brew --prefix sqlite3)"
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

