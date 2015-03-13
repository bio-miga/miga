#
# @package EGR (codename)
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Feb-23-2015
#

require 'egr/project'
require 'json'
require 'daemons'

module EGR
   class Daemon
      attr_reader :project
      def initialize(p)
	 @project = p
      end
      def default_options
         {:dir_mode=>:normal, :dir=>self.project.path+'/daemon', :multiple=>false, :log_output=>true}
      end
      def start() self.daemon('start') ; end
      def stop() self.daemon('stop') ; end
      def restart() self.daemon('restart') ; end
      def status() self.daemon('status') ; end
      def daemon(task, opts=[])
	 options = self.default_options
	 opts.unshift(task)
	 options[:ARGV] = opts
	 Daemons.run_proc("EGR:#{self.project.metadata[:name]}", options) do
	    p = self.project
	    self.say "EGR:#{p.metadata[:name]} launched."
	    loop do
	       p.datasets.each do |ds|
	          # Inspect preprocessing
		  ds.add_preprocessing
		  to_run = ds.next_preprocessing
		  unless to_run.nil?
		     # Launch task
		     self.say ds.name, ": Must launch task #{to_run}"
		  end
	       end
	       sleep(120)
	    end
	 end
      end
      def say(*opts)
	 print "[#{Time.new.inspect}] ", *opts, "\n"
      end
   end
end

