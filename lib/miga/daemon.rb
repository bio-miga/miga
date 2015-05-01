#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Apr-30-2015
#

require 'miga/project'
require 'json'
require 'daemons'

module MiGA
   class Daemon
      attr_reader :project, :options, :runopts, :jobs_to_run
      def initialize(p)
	 @project = p
	 @runopts = JSON.parse(File.read(self.project.path+"/daemon/daemon.json"), {:symbolize_names=>true})
	 @jobs_to_run = []
      end
      def default_options
         {:dir_mode=>:normal, :dir=>self.project.path+'/daemon', :multiple=>false, :log_output=>true}
      end
      def runopts(k, v=nil)
	 k = k.to_sym
	 unless v.nil?
	    v = v.to_i if [:latency, :maxjobs, :ppn].include? k
	    raise "Daemon's #{k} cannot be set to zero." if v.is_a? Integer and v==0
	    self.runopts[k] = v
	 end
	 self.runopts[k]
      end
      def latency() self.runopts[:latency] ; end
      def maxjobs() self.runopts[:maxjobs] ; end
      def ppn() self.runopts[:ppn] ; end
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
	    self.say "MiGA:#{p.metadata[:name]} launched."
	    loop do
	       p.datasets.each do |ds|
	          # Inspect preprocessing
		  ds.add_preprocessing
		  to_run = ds.next_preprocessing
		  unless to_run.nil?
		     # Launch task
		     self.say ds.name, ": Must launch task #{to_run}"
		     self.run_dataset_job ds, to_run
		  end
	       end
	       # ToDo Check if all the reference datasets are pre-processed. If yes, check the project-level tasks
	       
	       # Run jobs
	       self.flush!
	       sleep(self.latency)
	    end
	 end
      end
      def run_dataset_job(ds, job)
	 type = self.runopts(:type)
	 vars = {'DATASET'=>ds.name, 'PROJECT'=>ds.project.path}
	 to_run = {:cmd=>sprintf(self.runopts(:cmd),
	       File.expand_path(File.dirname(__FILE__) + "/../scripts/#{job.to_s}.#{self.runopts(:type)}"),
	       vars.each_pair{|k,v| sprintf(self.runopts(:var),k,v)}.join(self.runopts(:varsep)), self.ppn),
	       :ds=>ds, :job=>job}
	 @jobs_to_run << to_run
      end
      def run_project_job(job)
	 # ToDo launch a project-wide job
	 
      end
      def flush!
	 # ToDo Check for finished jobs
	 
	 # ToDo Launch as many @jobs_to_run as possible
	 
      end
      def say(*opts)
	 print "[#{Time.new.inspect}] ", *opts, "\n"
      end
   end
end

