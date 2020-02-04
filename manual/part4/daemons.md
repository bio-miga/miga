# Launching daemons

MiGA Daemons are centralized processes in MiGA that define which jobs need to
be executed, when, where, and how.
All of this can be controlled by customizing the daemons:

## Customizing daemons

### Daemon JSON file

When you initialize MiGA (`miga init`), the final step is generating a
daemon JSON file stored in `~/.miga_daemon.json`. This file will control the
type of daemon (see below) and the default configuration. In addition to this
user-wide file, each MiGA project has a `daemon/daemon.json` file. Any variables
defined here overwrite the user-wide file.

### `miga daemon`

When a daemon is launched using `miga daemon`, several configuration variables
can be overwritten using the different command-line flags.
If undefined, the variables will be defined by the `daemon/daemon.json` file in
the project, or by the daemon JSON file defined by `--json` if passed.
Finally, and if a variable is still missing from there, it will default to the
values in `~/.miga_daemon.json`.

### Workflows

Daemons are also launched by workflows.
This process is not manually controlled by the user, but it can also be
controlled in a number of ways.
First, the flags `--jobs` and `--threads` control the maximum number of jobs
(`maxjobs`) and the number of CPUs per job (`ppn`), respectively.
Next, a daemon JSON file can be defined using the flag `--daemon`.
Finally, variables that are not defined by either method will default to the
user-wide configuration in `~/.miga_daemon.json`.

## Daemon types

MiGA currently supports three daemon modes, and they each have specific details:

### Local daemons

Local daemons, or *bash* daemons, are the simplest mode.
You can use this type of daemon if you are launching MiGA in a single computer.

The most important consideration here is the *total number of available CPUs*.
When you launch a MiGA daemon, the maximum number of jobs spawned will be
determined by `--max-jobs` (or `maxjobs` in daemon JSON files, or `--jobs` in
workflows), whereas the number of CPUs each job can use is determined by `--ppn`
(or `ppn` in daemon JSON files, or `--threads` in workflows).
The number of jobs times the number of CPUs per job should never exceed the
number of CPUs available.
For example, if you have 12 cores in your computer, the default configuration of
6 jobs and 2 CPUs per jobs could use up to 100% of the available CPUs.

### Remote daemons

Remote daemons, or *ssh* daemons, are daemons that can communicate with other
machines to launch tasks remotely using a login shell through SSH.

The first consideration here is: the absolute path to the MiGA project and to
the MiGA system *must* be the same in all nodes (launcher and running nodes).
If this is not the case, remote executions will fail.

Next, in this type of daemon the trickiest part is to configure the remote nodes
correctly.
This is, to correctly *define the node list file*.
The node list file is a raw text file that contains the list of all remote nodes
available (hostnames), one per line.
It can be set as an environmental variable (*e.g.*, `$MIGA_NODELIST`) that will
be read at execution or explicitly as a path to the file.

Setting the node list file as a variable is useful when launching MiGA from a
scheduler-controlled system.
For example, when using Torque, this can be set to `$PBS_NODEFILE`.
On the other hand, a fixed file can be a useful alternative if you have a
defined set of nodes that are freely available to you (*e.g.*, a dedicated
infrastructure).

There are several ways to define the node list. First, it can be set using the
command-line flag `--node-list` in `miga daemon` (no equivalent is available for
workflows).
If this is not defined, daemons will look for the value of `nodelist` in the
daemon JSON files: first in `daemon/daemon.json` or in the file set by
`--daemon` (for workflows) or `--json` (for `miga daemon`), and finally in
`~/.miga_daemon.json`.
If the node list is set to a variable (starting with `$`), it must be defined as
an environmental varible.
For example, you could execute `export MIGA_NODELIST=/path/to/file.txt` before
running MiGA if the node list is set to `$MIGA_NODELIST`.

Finally, *remote daemons ignore `maxjobs`* (or `--max-jobs` or `--jobs`).
Instead, the maximum number of jobs is determined by the number of lines in the
node list.
This allows specifying how many jobs can be launched to each node.
For example, if a given node is present three times in the node list, MiGA will
run up to three jobs at the same time in that node.
Be careful when directly using node files defined by schedulers.
Some schedulers will list nodes on the basis of dedicated cores, which may be
a problem if the number of threads is more than 1
(`--ppn`, `ppn`, or `--threads`).
For example, consider the following PBS (Torque) script which you can use as a
template (assuming that `nodelist` is `$MIGA_NODELIST` and `type` is `ssh` in
`~/.miga_daemon.list`):

```bash
#PBS -q my_nice_queue
#PBS -l nodes=12:ppn=3
#PBS -l walltime=12:00:00

# Create the node list file
# Change the '3' by the number of CPUs you are using (the value of ppn):
awk 'NR % 3 == 0' < "$PBS_NODEFILE" > hosts.txt

# Define the nodelist variable:
export MIGA_NODELIST=hosts.txt

# Run MiGA (change the '3' by the value of ppn):
miga quality_wf -T 'Candidatus Macondimonas' -o Macondimonas -v --threads 3

```

### Scheduler daemons

Finally, daemons can also communicate directly with schedulers.
Currently, MiGA supports: *qsub* (Torque), *msub* (Moab), and *slurm* (SLURM).
If your HPCC runs a different scheduler and you'd like to see it added to this
list, [please contact us](http://support.microbial-genomes.org).

This is the preferred method when the flow of tasks is variable, because it
can easily adapt to different task loads.
For example, when maintaining a website that automatically processes incoming
jobs (like [MiGA Online](http://microbial-genomes.org)), the daemons are
low-resource tasks that launch as many or as few jobs as necessary.

Importantly, this method tends to require large numbers of jobs submitted to the
schedulers, and often wastes some requested resources since the resource use
configuration does not adapt to each task, both of which may be against your
HPCC policies.
Therefore, when processing a defined task in HPCC, it is preferred to use
either of the two modes above instead.
For example, if you want to evaluate the quality of four genomes, a good option
would be to launch a [local daemon](#local_daemons) with a maximum of 4 jobs
(`--max-jobs 4`).
On the other hand, if you have hundreds of genomes to process,
you could launch instead a [remote daemon](#remote_daemon).


