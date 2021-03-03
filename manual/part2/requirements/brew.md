# Live notebook

If you prefer to see code in action, the full installation process
with homebrew is available as a
[Notebook in Google Collab](https://colab.research.google.com/drive/1DhEMlcFwGgzW6q_fGEHLsihRSTK6ZRXD).

# Installing requirements using Homebrew

You can use [Homebrew](https://brew.sh/) to install most of the software
required by MiGA.
If you don't have Homebrew, execute (and follow the instructions):

```bash
/bin/bash -c "$(curl -fsSL \
  https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Packages

Now that you have Homebrew, execute:

```bash
brew tap brewsci/bio
brew install \
    r sqlite3 python adoptopenjdk \
    blast hmmer bedtools prodigal idba mcl \
    barrnap diamond fastani faqcs falco seqtk fastp
```

## A recent Ruby

It's possible you already have a recent version of ruby (2.3+).
To check which version you have, simply run: `ruby -v`.
If your version of Ruby is older than 2.3, you can install a recent
version using:

```bash
brew install libyaml rbenv
rbenv install 2.7.1
rbenv global 2.7.1
```

We also recommend installing the `sqlite3` gem beforehand using the brew
libraries, to avoid headaches down the road:

```bash
gem install sqlite3 -- --with-sqlite3-dir="$(brew --prefix sqlite3)"
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

