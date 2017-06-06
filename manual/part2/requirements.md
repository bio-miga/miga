# Requirements

MiGA requires a system (single computer, cluster, or cloud-computing
infrastructure) with Linux or MacOS. If you simply want to access projects
previously processed, all you need is `ruby` 1.9+ and the
[required gems](#ruby-libraries). If you want to use MiGA to process your data,
please continue these instructions.

MiGA has a relatively long list of requirements, but most of them are easy to
install. Find your system below and follow the instructions for:
[Linux users with `apt-get`](#for-linux-users-with-apt-get),
[MacOS users (or others with Homebrew)](#for-macos-users-or-others-with-homebrew),
or [any other users](#for-any-other-users).

## For Linux users with `apt-get`

### Essentials

If you have `apt-get`, execute:

```bash
# General-purpose software
sudo apt-get install ruby r-base sqlite3 python
# Bioinformatics software
sudo apt-get install ncbi-blast+ hmmer bedtools \
      prodigal idba mcl barrnap scythe fastqc
```

### SolexaQA++

Next, you'll need to install SolexaQA++. If you have a 64-bits Linux:

```bash
curl -L -o SolexaQA++_v3.1.7.1.zip "https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA%2B%2B_v3.1.7.1.zip"
unzip -p SolexaQA++_v3.1.7.1.zip Linux_x64/SolexaQA++ > SolexaQA++
sudo install SolexaQA++ /usr/bin/
```

If you have 32-bits Linux, you can build SolexaQA++ from source:

```bash
sudo apt-get install libboost-dev libboost-filesystem-dev \
      libboost-regex-dev libboost-iostreams-dev
curl -L -o SolexaQA++_v3.1.7.1.zip "https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA%2B%2B_v3.1.7.1.zip"
unzip SolexaQA++_v3.1.7.1.zip 'source/*'
cd source && make
sudo install source/SolexaQA++ /usr/bin/
```

### Ruby libraries

If you don't have direct writing privileges to the system gem repository, you
can either use `sudo gem ...` if you have superuser access, or
`gem install --user ...`:

```bash
gem install rest-client daemons json sqlite3
```

### R packages

This may take a while:

```bash
echo "
install.packages(c('enveomics.R','ape','phangorn','phytools','cluster','vegan'),
  repos='http://cran.rstudio.com/')" \
  | R --vanilla -q
```

### MyTaxa utils

**The MyTaxa utilities are optional**, but without them the
[MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa scan](../part5/workflow.md#mytaxa-scan) analyses are disabled. Note that
MyTaxa requires about **15Gb** of disk available to store the database.

We will install the necessary software in `$HOME/apps`. You can change this
directory if you prefer:

```bash
[[ -d $HOME/apps/bin ]] || mkdir -p $HOME/apps/bin
cd $HOME/apps

# Install Diamond
curl -L http://github.com/bbuchfink/diamond/releases/download/v0.9.4/diamond-linux64.tar.gz | tar zx
mv diamond diamond-sse2 bin/

# Install MyTaxa
curl -L https://github.com/luo-chengwei/MyTaxa/archive/master.tar.gz | tar zx
cd MyTaxa-master
make
python utils/download_db.py
curl -O http://enve-omics.ce.gatech.edu/data/public_mytaxa/AllGenomes.faa.dmnd
cd ..

# Install Krona
curl -L https://github.com/marbl/Krona/archive/master.tar.gz | tar zx
cd bin
for i in ../Krona-master/KronaTools/scripts/*.pl ; do
  ln -sf "$i" "kt$(basename $i .pl)"
done
cd ..
```

## For MacOS users (or others with Homebrew)

If you have MacOS, we'll use Homebrew to install most of the software. If
you don't have Homebrew, execute (and follow the instructions):

```bash
/usr/bin/ruby -e "$(curl -fsSL \
      https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Next, make sure you have the science tap:

```bash
brew tap homebrew/science
```

### Essentials

Now that you have Homebrew and the science tap, execute:

```bash
# General-purpose software
brew install r sqlite3 libsqlite3-dev python
# Bioinformatics software
brew install blast hmmer bedtools \
      prodigal idba mcl barrnap fastqc
brew install jonchang/biology/scythe
# Pending: Scythe in science (in pull request review)
# Missing: SolexaQA++ (in pull request review)
```

### Ruby libraries

If you don't have direct writing privileges to the system gem repository, you
can either use `sudo gem ...` if you have superuser access, or
`gem install --user ...`:

```bash
gem install sqlite3 -- \
  --with-sqlite3-lib=/usr/lib --with-sqlite3-include=/usr/include
gem install rest-client daemons json
```

### R packages

This may take a while:

```bash
echo "
install.packages(c('enveomics.R','ape','phangorn','phytools','cluster','vegan'),
  repos='http://cran.rstudio.com/')" \
  | R --vanilla -q
```

### MyTaxa utils

**The MyTaxa utilities are optional**, but without them the
[MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa scan](../part5/workflow.md#mytaxa-scan) analyses are disabled. Note that
MyTaxa requires about **15Gb** of disk available to store the database.

We will install the necessary software in `$HOME/apps`. You can change this
directory if you prefer:

```bash
[[ -d $HOME/apps/bin ]] || mkdir -p $HOME/apps/bin
cd $HOME/apps

# Install Diamond (using Homebrew)
brew install diamond

# Install MyTaxa
curl -L https://github.com/luo-chengwei/MyTaxa/archive/master.tar.gz | tar zx
cd MyTaxa-master
make
python utils/download_db.py
curl -O http://enve-omics.ce.gatech.edu/data/public_mytaxa/AllGenomes.faa.dmnd
cd ..

# Install Krona
curl -L -o Krona.tar.gz https://github.com/marbl/Krona/archive/master.tar.gz
tar zxf Krona.tar.gz
cd bin
for i in ../Krona-master/KronaTools/scripts/*.pl ; do
  ln -sf "$i" "kt$(basename $i .pl)"
done
cd ..
```

## For any other users

### Essentials

If you don't have either apt-get nor Homebrew, here's the list of requirements
and URLs with installation instructions:

* **Ruby**: https://www.ruby-lang.org/. Required version: 1.9+.
* **Python**: https://www.python.org/.
* **R**: http://www.r-project.org/.
* **SQLite3**: https://www.sqlite.org/.
* **NCBI BLAST+**: ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST.
* **HMMer**: http://hmmer.janelia.org/software. Required version: 3.0+.
* **Bedtools**: http://bedtools.readthedocs.org/en/latest/.
* **Prodigal**: http://prodigal.ornl.gov.
* **IDBA**: http://i.cs.hku.hk/~alse/hkubrg/projects/idba. Required flavor:
  IDBA-UD.
* **MCL**: http://micans.org/mcl/.
* **Barrnap**: http://www.vicbioinformatics.com/software.barrnap.shtml.
* **Scythe**: https://github.com/vsbuffalo/scythe. Required version: 0.991+.
* **FastQC**: http://www.bioinformatics.babraham.ac.uk/projects/fastqc.
* **SolexaQA++**: http://solexaqa.sourceforge.net. Required version: v3.1.3+.

### Ruby libraries

If you don't have direct writing privileges to the system gem repository, you
can either use `sudo gem ...` if you have superuser access, or
`gem install --user ...`:

```bash
gem install rest-client daemons json sqlite3
```

### R packages

This may take a while:

```bash
echo "
install.packages(c('enveomics.R','ape','phangorn','phytools','cluster','vegan'),
  repos='http://cran.rstudio.com/')" \
  | R --vanilla -q
```

### MyTaxa utils

**The MyTaxa utilities are optional**, but without them the
[MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa scan](../part5/workflow.md#mytaxa-scan) analyses are disabled. Note that
MyTaxa requires about **15Gb** of disk available to store the database.

To install **Diamond**, we provide below the method for 64-bits Linux. If you
have a different system please checkout https://github.com/bbuchfink/diamond
instead.

We will install the necessary software in `$HOME/apps`. You can change this
directory if you prefer:

```bash
[[ -d $HOME/apps/bin ]] || mkdir -p $HOME/apps/bin
cd $HOME/apps

# Install Diamond (for 64-bits Linux)
curl -L http://github.com/bbuchfink/diamond/releases/download/v0.9.4/diamond-linux64.tar.gz | tar zx
mv diamond diamond-sse2 bin/

# Install MyTaxa
curl -L https://github.com/luo-chengwei/MyTaxa/archive/master.tar.gz | tar zx
cd MyTaxa-master
make
python utils/download_db.py
curl -O http://enve-omics.ce.gatech.edu/data/public_mytaxa/AllGenomes.faa.dmnd
cd ..

# Install Krona
curl -L https://github.com/marbl/Krona/archive/master.tar.gz | tar zx
cd bin
for i in ../Krona-master/KronaTools/scripts/*.pl ; do
  ln -sf "$i" "kt$(basename $i .pl)"
done
cd ..
```
