# Setting up MiGA in a cluster

MiGA is developed to run on clusters with a TORQUE scheduler. The administrator
should install the [dependencies](/part2/requirements) and
[MiGA-base](/part2/installation) on a networked file system.

When you first initialize MiGA, the program will prompt the user for the type of
daemon. For a cluster with TORQUE, the user can choose a qsub daemon. During the
initialize, MiGA will also ask for the number of jobs to submit and the number
of CPUs per job.

After you have setup a MiGA project, you can create a job script to start
daemon. The daemon requires to be alive until all the jobs for the have
finished, so you should add a long-enough walltime. If you didn't give enough
walltime for your job, the MiGA daemon will get killed by the system. In this
case, you can restart the daemon again to finish processing the project.

Example job script:

```bash
#PBS -N MiGADaemon
#PBS -l mem=2gb
#PBS -l nodes=1:ppn2
#PBS -l walltime=48:00:00

cd $HOME/Path-to-project/
miga daemon start -P .
```
