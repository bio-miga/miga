# MiGA: Microbial Genomes Atlas

## What is MiGA?

MiGA is a data management and processing system for microbial genomes and  
metagenomes. It's main aim is to provide a uniform system for genome-based  
taxonomic classification and diversity studies, but its base can be used for  
other purposes.

* [How can MiGA help me?](part1/pitch.md).
* [Who's using MiGA?](part1/use-cases.md).
* [Definitions](glossary.md).

## Getting started with MiGA

MiGA iself doesn't require much, but processing large data collections may  
require large infrastructures. With that in mind, MiGA is designed to support  
both single machines and cluster infrastructures.

* [Requirements](part2/requirements.md).
* [Installation](part2/installation.md).
* [MiGA types](part2/types.md).
* [Distances](part2/distances.md).
* [Clustering](part2/clustering.md).

## MiGA Interfaces

You can interact with MiGA through different interfaces. These interfaces have  
different purposes, but they also have some degree of overlap, because different  
users with different aims sometimes want to do the same thing. The API and the  
CLI are the most comprehensive and flexible interfaces, but the other two are  
friendlier to humans. MiGA is mostly written in Ruby, with an object-oriented  
approach, and all the interfaces are just thin layers atop the Ruby core. That  
means that you can write your own interfaces \(or pieces\) if you know how to talk  
to these Ruby objects. Sometimes I even use `irb`, which is an interactive shell  
for Ruby, but that's mostly for debugging.

* [MiGA API](part3/API.md).
* [MiGA CLI](part3/CLI.md).
* [MiGA Web](part3/Web.md).

## Deploying examples

Once you have installed MiGA, you might want to follow one \(or several\) of these  
tutorials to familiarize yourself with the MiGA environment.

* [RefSeq in MiGA](part4/deploy-refseq.md).
* [Build a clade collection](part4/deploy-clade.md).
* [Launching daemons](part4/daemons.md).
* [Setting up MiGA in a cluster](part4/cluster.md).

## MiGA in detail

Ready for more? Here are some technical details for advanced users.

* [Advanced configuration](part5/advanced-configuration.md).
* [MiGA workflow](part5/workflow.md).
* [Extending MiGA](part5/extending.md).



