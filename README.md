MiGA: Microbial Genomes Atlas
=============================



Installation
------------



Getting started with MiGA
-------------------------

### Creating your first project

#### Project types

### Creating datasets

#### Dataset types

#### Non-reference datasets

### Registering results


Launching daemons
-----------------

### Configuring daemons


### Understating the MiGA configuration file [migarc]


### Arbitrary configuration scripts [migarc+]


### Fixing system calls with aliases [alias]

In some cases, we might not have the same executable names as MiGA expects, or we might have
broken modules in our cluster that can be easily fixed with an `alias`. In these cases, you can
use [arbitrary configuration scripts](#migarc+) to generate one or more `alias`. Importantly,
MiGA daemons work with non-interactive shells, which means you likely need to explicitly allow
for alias extensions, for example:

```bash
# Allow alias expansions in non-interactive shells
shopt -s expand_aliases

# Call FastQC with the environmental Perl,
# not the built-in /usr/bin/perl:
alias fastqc="perl $(which fastqc)"

# Use the standard name for RAxML (pthreads)
# instead of the one my sys-admin decided to use:
alias raxmlHPC-PTHREADS=RAxML_pthreads
```

The examples above illustrate how to use `alias` to fix broken packages or to make Software with
non-standard names reachable.

**Known caveats to this solution:** This solution CANNOT BE USED in the few cases in which a
whole package is expected based on a single executable. For example, adding the enveomics
scripts to your `PATH` is far easier than creating an `alias` for each script. Also, MiGA
expects to find the model, the activation key, and the scripts of MetaGeneMark in the same
folder of the `gmhmmp` binary, so setting an`alias` may prevent MiGA from finding these
ancillary files.


Cluster infrastructure
----------------------


### Loading optional modules [cluster-modules]


See also [Fixing system calls with aliases](#alias).



Authors
-------

Developed and maintained by [Luis M. Rodriguez-R](http://gplus.to/lrr).


License
-------



