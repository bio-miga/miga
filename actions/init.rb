#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require "shellwords"

o = {q:true, mytaxa:nil, config:File.expand_path(".miga_modules", ENV["HOME"]),
  ask: false, auto:false, dtype: "bash"}
OptionParser.new do |opt|
  opt_banner(opt)
  opt.on("-c","--config PATH",
    "Path to the Bash configuration file.",
    "By default: #{o[:config]}."){ |v| o[:config] = v }
  opt.on("--[no-]mytaxa",
    "Should I try setting up MyTaxa? By default: interactive."
    ){ |v| o[:mytaxa] = v }
  opt.on("--daemon-type STRING",
    "Type of daemon launcher, one of: bash, qsub, msub.",
    "By default: #{o[:dtype]}."){ |v| o[:dtype]=v }
  opt.on("--ask-all", "If set, asks for the location of all software.",
    "By default, only the locations missing in PATH are requested"
    ){ |v| o[:ask] = v }
  opt.on("--auto", "If set, accepts all defaults as answers."
    ){ |v| o[:auto] = v }
  opt_common(opt, o)
end.parse!
$auto_answer = o[:auto]

def ask_user(q, d=nil, ans=nil, force=false)
  $stderr.print "#{q}#{" (#{ans.join(" / ")})" unless ans.nil?}" +
    "#{"  [#{d}]" unless d.nil?} > "
  if $auto_answer and not force
    $stderr.puts ""
  else
    o = gets.chomp
  end
  o = d if o.nil? or o.empty?
  unless ans.nil? or ans.include? o
    $stderr.puts "Answer not recognized."
    return ask_user(q, d, ans)
  end
  o
end

##=> Main <=

miga = MiGA::MiGA.root_path
$stderr.puts <<BANNER
===[ Welcome to MiGA, the Microbial Genome Atlas ]===

I'm the initialization script, and I'll sniff around your computer to
make sure you have all the requirements for MiGA data processing.

BANNER

if ask_user(
      "Would you like to see all the requirements before starting?",
      "no", %w(yes no)) == "yes"
  File.open(File.expand_path("utils/requirements.txt", miga), "r") do |fh|
    fh.each_line{ |ln| $stderr.puts ln }
  end
end

rc_path = File.expand_path(".miga_rc", ENV["HOME"])
if File.exist? rc_path
  if ask_user(
        "I found a previous configuration. Do you want to continue?",
        "yes", %w(yes no))=="no"
    $stderr.puts "OK, see you soon!"
    exit 0
  end
end
rc_fh = File.open(rc_path, "w")
rc_fh.puts <<BASH
#!/bin/bash
# `miga init` made this on #{Time.now}

BASH

# Check bash configuration file
unless File.exist? o[:config]
  o[:config] = ask_user(
    "Is there a script I need to load at startup?", o[:config])
end
if File.exist? o[:config]
  o[:config] = File.expand_path o[:config]
  $stderr.puts "Found bash configuration script: #{o[:config]}."
  rc_fh.puts "MIGA_STARTUP='#{o[:config]}'"
  rc_fh.puts "source \"$MIGA_STARTUP\""
end
$stderr.puts ""

# Check for software requirements
$stderr.puts "Looking for requirements:"
if o[:mytaxa].nil?
  o[:mytaxa] = ask_user(
        "Should I include MyTaxa modules?","yes",%w(yes no))=="yes"
end
rc_fh.puts "export MIGA_MYTAXA=\"no\"" unless o[:mytaxa]
paths = {}
File.open(File.expand_path("utils/requirements.txt", miga), "r") do |fh|
  fh.each_line do |ln|
    next if $. < 3
    r = ln.chomp.split(/\t+/)
    next if r[0] =~ /\(opt\)$/ and not o[:mytaxa]
    $stderr.print "Testing #{r[0]}#{" (#{r[3]})" if r[3]}... "
    path = nil
    loop do
      d_path = File.dirname(`which "#{r[1]}"`)
      if o[:ask] or d_path=="."
        path = ask_user("Where can I find it?", d_path, nil, true)
      else
        path = d_path
        $stderr.puts path
      end
      if File.executable? File.expand_path(r[1], path)
        if d_path != path
          rc_fh.puts "MIGA_PATH=\"#{path}:$MIGA_PATH\" # #{r[1]}"
        end
        break
      end
      $stderr.print "I cannot find #{r[1]}. "
    end
    paths[r[1]] = File.expand_path(r[1], path).shellescape
  end
end
rc_fh.puts "export PATH=\"$MIGA_PATH$PATH\""
$stderr.puts ""

# Check for other files
if o[:mytaxa]
  $stderr.puts "Looking for MyTaxa databases:"
  mt = File.dirname paths["MyTaxa"]
  $stderr.print "Looking for scores... "
  unless Dir.exist? File.expand_path("db", mt)
    $stderr.puts "no.\nExecute 'python #{mt}/utils/download_db.py'."
    exit 1
  end
  $stderr.puts "yes."
  $stderr.print "Looking for diamond db... "
  unless File.exist? File.expand_path("AllGenomes.faa.dmnd", mt)
    $stderr.puts "no.\nDownload " +
      "'http://enve-omics.ce.gatech.edu/data/public_mytaxa/" +
      "AllGenomes.faa.dmnd' into #{mt}."
    exit 1
  end
  $stderr.puts ""
end

# Check for R packages
$stderr.puts "Looking for R packages:"
%w(enveomics.R ape phangorn phytools cluster vegan).each do |pkg|
  $stderr.print "Testing #{pkg}... "
  `echo "library('#{pkg}')" | #{paths["R"].shellescape} --vanilla -q 2>&1`
  if $?.success?
    $stderr.puts "yes."
  else
    $stderr.puts "no, installing."
    $stderr.print "" +
      `echo "install.packages('#{pkg}', repos='http://cran.rstudio.com/')" \
            | #{paths["R"].shellescape} --vanilla -q 2>&1`
    `echo "library('#{pkg}')" | #{paths["R"].shellescape} --vanilla -q 2>&1`
    raise "Unable to auto-install R package #{pkg}." unless $?.success?
  end
end
$stderr.puts ""

# Check for Ruby gems
$stderr.puts "Looking for Ruby gems:"
%w(rest-client sqlite3 daemons json).each do |pkg|
  $stderr.print "Testing #{pkg}... "
  `#{paths["ruby"].shellescape} -r "#{pkg}" -e "" 2>/dev/null`
  if $?.success?
    $stderr.puts "yes."
  else
    $stderr.puts "no, installing."
    # This hackey mess is meant to ensure the test and installation are done
    # on the configuration Ruby, not on the Ruby currently executing the init
    # action
    $stderr.print `#{paths["ruby"].shellescape} \
        -r rubygems -r rubygems/gem_runner \
        -e "Gem::GemRunner.new.run %w(install --user #{pkg})" 2>&1`
    raise "Unable to auto-install Ruby gem #{pkg}." unless $?.success?
  end
end
$stderr.puts ""

# Configure daemon
$stderr.puts "Default daemon configuration:"
v = {created:Time.now.to_s, updated:Time.now.to_s}
v[:type] = ask_user("Please select the type of daemon you want to setup",
          o[:dtype], %w(bash qsub msub))
case v[:type]
  when "bash"
    v[:latency] = ask_user("How long should I sleep? (in seconds)","30").to_i
    v[:maxjobs] = ask_user("How many jobs can I launch at once?", "6").to_i
    v[:ppn]     = ask_user("How many CPUs can I use per job?", "2").to_i
    $stderr.puts "Setting up internal daemon defaults."
    $stderr.puts "If you don't understand this just leave default values:"
    v[:cmd]     = ask_user(
      "How should I launch tasks?\n  %1$s: script path, %2$s: variables, " +
      "%3$d: CPUs, %4$s: log file, %5$s: task name.\n",
      "%2$s '%1$s' > '%4$s' 2>&1")
    v[:var]     = ask_user(
      "How should I pass variables?\n  %1$s: keys, %2$s: values.\n",
      "%1$s=%2$s")
    v[:varsep]  = ask_user("What should I use to separate variables?", " ")
    v[:alive]   = ask_user(
      "How can I know that a process is still alive?\n  %1$s: PID, " +
      "output should be 1 for running and 0 for non-running.\n",
      "ps -p '%1$s'|tail -n+2|wc -l")
    v[:kill]    = ask_user(
      "How should I terminate tasks?\n  %s: process ID.", "kill -9 '%s'")
  else # [qm]sub
    queue       = ask_user("What queue should I use?", nil, nil, true)
    v[:latency] = ask_user("How long should I sleep? (in seconds)", "150").to_i
    v[:maxjobs] = ask_user("How many jobs can I launch at once?", "300").to_i
    v[:ppn]     = ask_user("How many CPUs can I use per job?", "4").to_i
    $stderr.puts "Setting up internal daemon defaults."
    $stderr.puts "If you don't understand this just leave default values:"
    v[:cmd]     = ask_user(
      "How should I launch tasks?\n  %1$s: script path, %2$s: variables, " +
      "%3$d: CPUs, %4$d: log file, %5$s: task name.\n",
      "#{v[:type]} -q '#{queue}' -v '%2$s' -l nodes=1:ppn=%3$d %1$s " +
      "-j oe -o '%4$s' -N '%5$s' -l mem=9g -l walltime=12:00:00 | grep .")
    v[:var]     = ask_user(
      "How should I pass variables?\n  %1$s: keys, %2$s: values.\n",
      "%1$s=%2$s")
    v[:varsep]  = ask_user("What should I use to separate variables?", ",")
    if v[:type] == "qsub"
      v[:alive] = ask_user(
        "How can I know that a process is still alive?\n  %1$s: job id, " +
        "output should be 1 for running and 0 for non-running.\n",
        "qstat -f '%1$s'|grep ' job_state ='|perl -pe 's/.*= //'|grep '[^C]'" +
        "|tail -n1|wc -l|awk '{print $1}'")
    v[:kill]    = ask_user(
      "How should I terminate tasks?\n  %s: process ID.", "qdel '%s'")
    else
      v[:alive] = ask_user(
        "How can I know that a process is still alive?\n  %1$s: job id, " +
        "output should be 1 for running and 0 for non-running.\n",
        "checkjob '%1$s'|grep '^State:'|perl -pe 's/.*: //'" +
        "|grep 'Deferred\\|Hold\\|Idle\\|Starting\\|Running\\|Blocked'"+
        "|tail -n1|wc -l|awk '{print $1}'")
    v[:kill]    = ask_user(
      "How should I terminate tasks?\n  %s: process ID.", "canceljob '%s'")
    end
end
File.open(File.expand_path(".miga_daemon.json", ENV["HOME"]), "w") do |fh|
  fh.puts JSON.pretty_generate(v)
end
$stderr.puts ""

rc_fh.puts <<FOOT

MIGA_CONFIG_VERSION='#{MiGA::MiGA.VERSION}'
MIGA_CONFIG_LONGVERSION='#{MiGA::MiGA.LONG_VERSION}'
MIGA_CONFIG_DATE='#{Time.now}'

FOOT

$stderr.puts "Configuration complete. MiGA is ready to work!"
$stderr.puts ""
