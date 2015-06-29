#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jun-28-2015
#

require 'miga/project'
require 'shoes'
require 'shoes/swt'

Shoes::Swt.initialize_backend

module MiGA
   class MiGA
      @@STATUS = "Initializing MiGA..."
      def self.STATUS=(status) @@STATUS = status ; end
      def self.STATUS() @@STATUS; end
      def self.RESET_STATUS() @@STATUS="MiGA is ready to go!" ; end
   end
   class GUI < Shoes
      url '/', :index
      url '/project', :project
      $miga_path = File.expand_path(File.dirname(__FILE__) + "/../../")

      def self.init (&block)
	 Shoes.app title: "MiGA | Microbial Genomes Atlas", width: 750, height: 400, &block
      end
      
      # =====================[ View : Windows ]
      # Main MiGA window
      def index
	 status_bar
	 stack do
	    title "Welcome to MiGA!", align:"center"
	    flow do
	       stack margin: 21
	       menu_bar [:open_project, :new_project, :help]
	    end
	    image $miga_path + "/gui/img/MiGA-bg.png", margin:10, width:170, height:70
	 end
	 MiGA.RESET_STATUS
      end

      # MiGA Project window
      def project
	 stack do
	    title $project.metadata[:name], align:"center"
	    caption $project.path, align:"center"
	    stack do
	       stack margin: 120
	       menu_bar [:list_datasets, :new_dataset, :process_report, :help]
	    end
	    MiGA.RESET_STATUS
	 end
      end
      
      # =====================[ View : Elements ]
      # Menu bar
      def menu_bar actions
	 flow left: 20 do
	    b = {
	       open_project:["Open project", "iconmonstr-archive-5-icon-256"],
	       new_project:["New project","iconmonstr-plus-5-icon-256"],
	       list_datasets:["List datasets", "iconmonstr-note-10-icon-256"],
	       new_dataset:["New dataset", "iconmonstr-note-25-icon-256"],
	       process_report:["Process report", "iconmonstr-bar-chart-2-icon-256"],
	       help:["Help", "iconmonstr-help-3-icon-256"]
	    }
	    actions.each do |k|
	       v = b[k]
	       flow(margin:0, width:200) do
		  image $miga_path + "/gui/img/#{v[1]}.png", width:40, height:40, margin:2
		  button v[0], top:5 do
		     MiGA.STATUS = "Calling #{k}..."
		     eval k.to_s
		  end
	       end
	    end
	 end
      end # menu_bar
      
      # Status bar
      def status_bar
	 stack(bottom:0) do
	    flow bottom:0, height:20, margin:0 do
	       background "#CCC"
	       stack(width:50)
	       $status_cont = stack(width:-300, height:1.0)
	       every do |i|
		  $status_cont.clear { inscription MiGA.STATUS, margin:5 }
	       end
	       stack(width:250, height:1.0) do
		  inscription MiGA.LONG_VERSION, align:"right", margin:5
	       end
	    end
	    image $miga_path + "/gui/img/MiGA-sq.png", left:0, bottom:0, width:30, height:32
	 end
      end # status_bar

      # =====================[ Controller : Projects ]
      def open_project
	 GUI.init do
	    folder = ask_open_folder
	    if folder.nil? or not Project.exist? folder
	       alert "Cannot find a MiGA project at #{folder}!" unless folder.nil?
	       return
	    else
	       $project = Project.new folder
	       visit '/project'
	    end
	 end
      end # open_project
      def new_project
	 GUI.init do
	    folder = ask_save_folder
	    if folder.nil? or Project.exist? folder
	       alert "Cannot overwrite existent MiGA project at #{folder}!" unless folder.nil?
	       return
	    else
	       $project = Project.new folder
	       visit '/project'
	    end
	 end
      end # new_project
   end
end

