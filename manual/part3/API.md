# MiGA API

API stands for Application Program Interface. This is the inner-most layer in
the MiGA system, allowing direct interaction with the Ruby infrastructure of
MiGA.

## Installation

If you use Rubygems simply type:

```bash
gem install miga-base
```

Or to build from source:
```bash
git clone https://github.com/bio-miga/miga.git
cd miga
gem build miga-base.gemspec
gem install miga-base-*.gem
```

## Usage

Now that you have the gem, you can use the [CLI](CLI), but you can also
interact directly with the API. The `actions` folder contains the CLI
implementations, so you can take them as examples on how to use the API. You
can also use `irb`. For example:

```ruby
irb -r miga
irb%> MiGA::Project.exist? "test_project"
false
irb%> p = MiGA::Project.new("test_project")
=> #<MiGA::Project:0x007ffa47014b60 @path="/Users/lmr3/miga/test_project", @metadata=#<MiGA::Metadata:0x007ffa47014890 @path="/Users/lmr3/miga/test_project/miga.project.json", @data={:datasets=>[], :name=>"test_project", :created=>"2016-03-29 17:44:58 -0400", :updated=>"2016-03-29 17:44:58 -0400"}>>
irb%> MiGA::Project.exist? "test_project"
true
```

That's a simple example of a session checking if the `test_project` already
exists, and then creating it. For a complete documentation of the API, check
out the [miga gem docs](docs.microbial-genomes.org).

