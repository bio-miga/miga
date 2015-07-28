MiGA: Microbial Genomes Atlas
=============================



Installation
------------

Please see [INSTALLATION.md](./INSTALLATION.md) for instructions.

Getting started with MiGA
-------------------------

### MiGA Interfaces

You caninteract with MiGA through different interfaces. These interfaces have
different purposes, but they also have some degree of overlap, because different
users with different aims sometimes want to do the same thing. Throughout this
manual I'll be telling you how to do things using mostly the CLI, but I'll also
try to mention the GUI and the Web Interface. The CLI is the most comprehensive
and flexible interface, but the other two are friendlier to humans. There is a
fourth interface that I won't be mentioning at all, but I'll try to document:
the Ruby API. MiGA is mostly written in Ruby, with an object-oriented approach,
and all the interfaces are just thin layers atop the Ruby core. That means that
you can write your own interfaces (or pieces) if you know how to talk to these
Ruby objects. Sometimes I even use `irb`, which is an interactive shell for
Ruby, but that's mostly for debugging.

#### MiGA CLI

CLI stands for Command Line Interface. This is a set of little scripts that let
you talk with MiGA through the terminal shell. If MiGA is in your PATH (see
[installation details](./INSTALLATION.md#miga-in-your-path)), you can simply run
`miga` in your terminal, and the help messages will take it from there. All the
MiGA CLI calls look like:

```bash
miga task [options]
```

Where `task` is one of the supported tasks and `[options]` is a set of dash-flag
options supported by each task. `-h` is always there to provide help. If you're
a MiGA administrator, this is probably the most convenient option for you (but
hey, give the GUI a chance).

#### MiGA GUI

The Graphical User Interface is the friendlier option for setting up a MiGA
project. It doesn't have as many options as the CLI, but it's pretty easy to
use, so it's a good option if you have a typical project in your hands.

#### MiGA Web

The Web interface for MiGA is the way MiGA reports results from a project. It's
not designed to set up new projects, but to explore existing ones, and to submit
non-reference datasets for analyses.

### Creating your first project

You can do this in the GUI, but I like the CLI better, so I'll be telling you
how to tell MiGA what to do from the CLI. First, think where you'll place your
project. Normally this means a location...

1. ... with enough space. This is, plan for at least 4 or 5 times the size of
the input files.

2. ... accessible by worker nodes. If you're using a single server, this is not
really an issue. However, if you plan on deploying MiGA in a cluster
infrastructure, make sure your project is reachable by worker nodes.

3. ... with fast access. It's not a great idea to set up projects in remote
drives with large latency. In some cases there no way around this, for example
when that's the only available option in your cluster infrastructure, but try
to avoid this as much as possible.

Now that you know where to create your project, go ahead and run:
```bash
miga create_project -P /path/to/project -t type-of-project
```

Where `/path/to/project` is the path to where the project should be created. You
don't need to create the folder in advance, MiGA will take care. See the next
section to help you decide what `type-of-project` to use. There are some other
options that are not mandatory, but will make your project richer. Take a look
at `miga create\_project -h`.

#### Project types



### Creating datasets

#### Dataset types

#### Non-reference datasets

### Registering results


Launching daemons
-----------------

### Configuring daemons


### Understating the MiGA configuration file


### Arbitrary configuration scripts


### Fixing system calls with aliases

In some cases, we might not have the same executable names as MiGA expects, or we might have
broken modules in our cluster that can be easily fixed with an `alias`. In these cases, you can
use [arbitrary configuration scripts](#arbitrary-configuration-scripts) to generate one or more
`alias`. Importantly, MiGA daemons work with non-interactive shells, which means you likely need
to explicitly allow for alias extensions, for example:

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


### Loading optional modules


See also [Fixing system calls with aliases](#fixing-system-calls-with-aliases).



Authors
-------

Developed and maintained by [Luis M. Rodriguez-R](http://gplus.to/lrr).


License
-------



