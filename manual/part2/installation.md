# Installation

## Prerequisites

If you simply want to access projects previously processed, you can skip this
step.

Once you have satisfied all the [system requirements](requirements.md), you'll
need to make them accessible to MiGA. For that, create a `bash` configuration
file at `~/.miga_modules` loading any necessary packages (*e.g.*, if you're
in a cluster architecture using `modules`, this is where you should load them).
Here's an example of a configuration file for a single computer:

```bash
#!/bin/bash
# File: ~/.miga_modules

# Enable software installed in this user
export PATH="$HOME/apps/bin:$PATH"

# Enable MyTaxa
export PATH="$HOME/apps/MyTaxa:$PATH"
```

Here is an example of a configuration file for a cluster:

```bash
#!/bin/bash
# File: ~/.miga_modules

shopt -s expand_aliases
module purge
module load gcc/4.9.0
module load ruby/2.1.5
module load R/3.3.2
module load prodigal/2.6.1
module load bedtools/2.21.0
module load scythe/0.993
module load fastqc/0.11.2
module load idba/1.1.1_kMSS
module load hmmer/3.1b1

# Enable MyTaxa
export PATH="$HOME/shared3/apps/MyTaxa:$PATH"

# Workaround for broken FastQC in the cluster
alias fastqc="perl $(which --skip-alias --skip-functions fastqc)"

# Workaround for broken KronaTools in the cluster
alias ktImportText="perl -I$HOME/shared3/apps/KronaTools-2.5/lib/ $HOME/shared3/bin/ktImportText"
```

If all of the requirements are readily available (*e.g.*, if you already
registered them in your `~/.bashrc`), this file can be empty or nonexistent.

## Getting MiGA

To install MiGA itself, you'll just need: `gem install miga-base`. If necessary,
you can use `sudo gem install miga-base` or `gem install --user miga-base`
instead.

### Getting MiGA source

If you want to get MiGA working from source instead of using the gem, you can
use:

```bash
# Get the source. Make sure you use --recursive, so you also clone submodules:
git clone --recursive https://github.com/bio-miga/miga.git
cd miga

# You can use bundle to make sure you have the required gems, or simply install
# them manually:
bundle

# And finally make MiGA available in the PATH. This is not completely necessary,
# but it saves time and effort:
echo "export PATH=\"$(pwd)/bin:\$PATH\"" >> ~/.bashrc
source ~/.bashrc
```

## Initializing MiGA

To initialize MiGA for data processing, simply execute and follow the
instructions:

```bash
miga init
```

To see additional initialization parameters, use `miga init -h`.
