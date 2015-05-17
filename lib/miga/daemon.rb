#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update May-17-2015
#

require 'miga/project'
require 'json'
require 'daemons'

module MiGA
   class Daemon
      attr_reader :project, :options, :jobs_to_run, :jobs_running
      def initialize(p)
	 @project = p
	 @runopts = JSON.parse(File.read(self.project.path+"/daemon/daemon.json"), {:symbolize_names=>true})
	 @jobs_to_run = []
	 @jobs_running = []
      end
      def default_options
         {:dir_mode=>:normal, :dir=>self.project.path+'/daemon', :multiple=>false, :log_output=>true}
      end
      def runopts(k, v=nil)
	 k = k.to_sym
	 unless v.nil?
	    v = v.to_i if [:latency, :maxjobs, :ppn].include? k
	    raise "Daemon's #{k} cannot be set to zero." if v.is_a? Integer and v==0
	    @runopts[k] = v
	 end
	 @runopts[k]
      end
      def latency() self.runopts(:latency) ; end
      def maxjobs() self.runopts(:maxjobs) ; end
      def ppn() self.runopts(:ppn) ; end
      def start() self.daemon('start') ; end
      def stop() self.daemon('stop') ; end
      def restart() self.daemon('restart') ; end
      def status() self.daemon('status') ; end
      def daemon(task, opts=[])
	 options = self.default_options
	 opts.unshift(task)
	 options[:ARGV] = opts
	 Daemons.run_proc("MiGA:#{self.project.metadata[:name]}", options) do
	    p = self.project
	    self.say "-----------------------------------"
	    self.say "MiGA:#{p.metadata[:name]} launched."
	    self.say "-----------------------------------"
	    loop_i = 0
	    loop do
	       loop_i += 1
	       # Traverse datasets
	       p.datasets.each do |ds|
	          # Inspect preprocessing
		  to_run = ds.next_preprocessing
		  # Launch task
		  self.queue_job(to_run, ds) unless to_run.nil?
	       end
	       
	       # Check if all the reference datasets are pre-processed. If yes, check the project-level tasks
	       if p.done_preprocessing?
		  to_run = p.next_distances
		  to_run = p.next_inclade if to_run.nil?
		  # Launch task
		  self.queue_job(to_run) unless to_run.nil?
	       end
	       
	       # Run jobs
	       self.flush!

	       # Every 12 loops:
	       if loop_i==12
		  self.say "Housekeeping for sanity"
		  loop_i = 0
		  # Check if running jobs are alive
		  self.purge!
		  # Reload project metadata (to add newly created datasets)
		  self.project.load
	       end
	       sleep(self.latency)
	    end
	 end
      end
      def queue_job(job, ds=nil)
	 return nil unless self.get_job(job, ds).nil?
	 ds_name = (ds.nil? ? "miga-project" : ds.name)
	 self.say "Queueing ", ds_name, ":#{job}"
	 type = self.runopts(:type)
	 vars = {'PROJECT'=>self.project.path, 'RUNTYPE'=>self.runopts(:type), 'CORES'=>self.ppn, 'MIGA'=>File.expand_path(File.dirname(__FILE__) + "/../..")}
	 vars['DATASET'] = ds.name unless ds.nil?
	 log_dir = self.project.path + "/daemon/#{job.to_s}"
	 Dir.mkdir log_dir unless Dir.exist? log_dir
	 to_run = {:ds=>ds, :job=>job, :cmd=>sprintf(self.runopts(:cmd),
	       # 1: script
	       vars['MIGA'] + "/scripts/#{job.to_s}.bash",
	       # 2: vars
	       vars.keys.map{|k| sprintf(self.runopts(:var),k,vars[k])}.join(self.runopts(:varsep)),
	       # 3: CPUs
	       self.ppn,
	       # 4: log file
	       log_dir + "/#{ds_name}.log")}
	 @jobs_to_run << to_run
      end
      def get_job(job, ds=nil)
	 if ds==nil
	    (@jobs_to_run + @jobs_running).select{ |j| (j[:ds].nil?) and (j[:job]==job) }.first
	 else
	    (@jobs_to_run + @jobs_running).select{ |j| (not j[:ds].nil?) and (j[:ds].name==ds.name) and (j[:job]==job) }.first
	 end
      end
      def flush!
	 # Check for finished jobs
	 self.jobs_running.select! do |job|
	    r = job[:ds].nil? ? self.project.add_result(job[:job]) : job[:ds].add_result(job[:job])
	    self.say "Completed pid:#{job[:pid]} for #{job[:ds].nil? ? "" : "#{job[:ds].name}:"}#{job[:job]}" unless r.nil?
	    r.nil?
	 end
	 
	 # Avoid single datasets hogging resources
	 @jobs_to_run.rotate! rand(@jobs_to_run.size)
	 
	 # Launch as many @jobs_to_run as possible
	 while self.jobs_running.size < self.maxjobs
	    break if self.jobs_to_run.empty?
	    job = self.jobs_to_run.shift
	    if self.runopts(:type)=='bash'
	       job[:pid] = spawn job[:cmd]
	       Process.detach job[:pid]
	    else
	       job[:pid] = `#{job[:cmd]}`.gsub(/[\n\r]/,'')
	    end
	    @jobs_running << job
	    self.say "Spawned pid:#{job[:pid]} for #{job[:ds].nil? ? "" : "#{job[:ds].name}:"}#{job[:job]}"
	 end
      end
      def purge!
	 self.jobs_running.select!{ |job| `#{sprintf(self.runopts(:alive), job[:pid])}`.chomp.to_i == 1 }
      end
      def say(*opts)
	 print "[#{Time.new.inspect}] ", *opts, "\n"
      end
   end
end

