#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Nov-12-2015
#

require "miga/project"
require "daemons"
require "date"

module MiGA
   class Daemon
      def self.last_alive(p)
         f = File.expand_path("daemon/alive", p.path)
	 return nil unless File.size? f
	 DateTime.parse(File.read(f))
      end
      
      attr_reader :project, :options, :jobs_to_run, :jobs_running
      def initialize(p)
	 @project = p
	 @runopts = JSON.parse(
	    File.read(File.expand_path("daemon/daemon.json", project.path)),
	    {:symbolize_names=>true})
	 @jobs_to_run = []
	 @jobs_running = []
      end
      def last_alive
	 Daemon.last_alive project
      end
      def default_options
         { dir_mode: :normal, dir: File.expand_path("daemon", project.path),
	    multiple: false, log_output: true }
      end
      def runopts(k, v=nil)
	 k = k.to_sym
	 unless v.nil?
	    v = v.to_i if [:latency, :maxjobs, :ppn].include? k
	    raise "Daemon's #{k} cannot be set to zero." if
	       v.is_a? Integer and v==0
	    @runopts[k] = v
	 end
	 @runopts[k]
      end
      def latency() runopts(:latency) ; end
      def maxjobs() runopts(:maxjobs) ; end
      def ppn() runopts(:ppn) ; end
      def start() daemon("start") ; end
      def stop() daemon("stop") ; end
      def restart() daemon("restart") ; end
      def status() daemon("status") ; end
      def daemon(task, opts=[])
	 options = default_options
	 opts.unshift(task)
	 options[:ARGV] = opts
	 Daemons.run_proc("MiGA:#{project.metadata[:name]}", options) do
	    p = project
	    say "-----------------------------------"
	    say "MiGA:#{p.metadata[:name]} launched."
	    say "-----------------------------------"
	    loop_i = 0
	    loop do
	       # Tell the world you're alive
	       f = File.open(File.expand_path("daemon/alive", project.path),"w")
	       f.print Time.now.to_s
	       f.close
	       loop_i += 1
	       # Traverse datasets
	       p.datasets.each do |ds|
	          # Inspect preprocessing
		  to_run = ds.next_preprocessing(true)
		  # Launch task
		  queue_job(to_run, ds) unless to_run.nil?
	       end
	       
	       # Check if all the reference datasets are pre-processed.
	       # If yes, check the project-level tasks
	       if p.done_preprocessing?(true)
		  to_run = p.next_distances
		  to_run = p.next_inclade if to_run.nil?
		  # Launch task
		  queue_job(to_run) unless to_run.nil?
	       end
	       
	       # Run jobs
	       flush!

	       # Every 12 loops:
	       if loop_i==12
		  say "Housekeeping for sanity"
		  loop_i = 0
		  # Check if running jobs are alive
		  purge!
		  # Reload project metadata (to add newly created datasets)
		  project.load
	       end
	       sleep(latency)
	    end
	 end
      end
      def queue_job(job, ds=nil)
	 return nil unless get_job(job, ds).nil?
	 ds_name = (ds.nil? ? "miga-project" : ds.name)
	 say "Queueing ", ds_name, ":#{job}"
	 type = runopts(:type)
	 vars = {
	    "PROJECT"=>project.path, "RUNTYPE"=>runopts(:type), "CORES"=>ppn,
	    "MIGA"=>File.expand_path("../..", File.dirname(__FILE__)) }
	 vars["DATASET"] = ds.name unless ds.nil?
	 log_dir = File.expand_path("daemon/#{job}", project.path)
	 Dir.mkdir log_dir unless Dir.exist? log_dir
	 to_run = {ds: ds, job: job, cmd: sprintf(runopts(:cmd),
	       # 1: script
	       vars["MIGA"] + "/scripts/#{job.to_s}.bash",
	       # 2: vars
	       vars.keys.map{|k| sprintf(runopts(:var),k,vars[k])
		  }.join(runopts(:varsep)),
	       # 3: CPUs
	       ppn,
	       # 4: log file
	       File.expand_path("#{ds_name}.log", log_dir),
	       # 5: task name
	       "#{project.metadata[:name][0..9]}:#{job}:#{ds_name}")}
	 @jobs_to_run << to_run
      end
      def get_job(job, ds=nil)
	 if ds==nil
	    (@jobs_to_run + @jobs_running).select do |j|
	       (j[:ds].nil?) and (j[:job]==job)
	    end.first
	 else
	    (@jobs_to_run + @jobs_running).select do |j|
	       (not j[:ds].nil?) and (j[:ds].name==ds.name) and (j[:job]==job)
	    end.first
	 end
      end
      def flush!
	 # Check for finished jobs
	 self.jobs_running.select! do |job|
	    r = job[:ds].nil? ?
	       self.project.add_result(job[:job]) :
	       job[:ds].add_result(job[:job])
	    say "Completed pid:#{job[:pid]} for " + 
	       "#{job[:ds].nil? ? "" : "#{job[:ds].name}:"}#{job[:job]}" unless
	       r.nil?
	    r.nil?
	 end
	 
	 # Avoid single datasets hogging resources
	 @jobs_to_run.rotate! rand(@jobs_to_run.size)
	 
	 # Launch as many @jobs_to_run as possible
	 while jobs_running.size < maxjobs
	    break if jobs_to_run.empty?
	    job = self.jobs_to_run.shift
	    if runopts(:type) == "bash"
	       job[:pid] = spawn job[:cmd]
	       Process.detach job[:pid]
	    else
	       job[:pid] = `#{job[:cmd]}`.gsub(/[\n\r]/,"")
	    end
	    @jobs_running << job
	    say "Spawned pid:#{job[:pid]} for " +
	       "#{job[:ds].nil? ? "" : "#{job[:ds].name}:"}#{job[:job]}"
	 end
      end
      def purge!
	 self.jobs_running.select! do |job|
	    `#{sprintf(runopts(:alive), job[:pid])}`.chomp.to_i == 1
	 end
      end
      def say(*opts)
	 print "[#{Time.new.inspect}] ", *opts, "\n"
      end
   end
end

