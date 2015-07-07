#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jul-07-2015
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
      url '/datasets', :datasets
      url '/dataset-(.*)', :dataset
      url '/report', :report
      $miga_path = File.expand_path(File.dirname(__FILE__) + "/../../")

      def self.init (&block)
	 Shoes.app title: "MiGA | Microbial Genomes Atlas", width: 750, height: 400, &block
      end
      
      # =====================[ View : Windows ]
      # Main window
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

      # Project window
      def project
	 stack do
	    title $project.metadata[:name], align:"center"
	    caption $project.path, align:"center"
	    stack do
	       stack margin: 120
	       menu_bar [:list_datasets, :new_dataset, :process_report, :help]
	    end
	    stack(margin: 20) do
	       para strong("Datasets"), ": ", $project.metadata[:datasets].size
	       $project.metadata.each { |k,v| para(strong(k), ": ", v) unless k==:datasets }
	    end
	    MiGA.RESET_STATUS
	 end
      end

      # Datasets list window
      def datasets
	 stack do
	    title $project.metadata[:name], align:"center"
	    caption $project.path, align:"center"
	    stack(margin:20) do
	       stack margin: 120
	       para "Displaying #{$project.metadata[:datasets].size} datasets:"
	       stack margin: 120
	       $project.metadata[:datasets].each do |name|
		  para link(name, :click=>"/dataset-#{name}")
	       end
	    end
	    MiGA.RESET_STATUS
	 end
      end

      # Dataset details window
      def dataset(name)
	 stack do
	    ds = $project.dataset(name)
	    title ds.name, align:"center"
	    caption "A dataset in ", strong(link($project.metadata[:name], :click=>"/datasets")), align:"center"
	    stack(margin:20) do
	       stack margin: 120
	       ds.metadata.each { |k,v| para strong(k), ": ", v }
	    end
	    flow do
	       w = 40+30*Dataset.PREPROCESSING_TASKS.size
	       stack(margin:20, width:w) do
		  subtitle "Advance:"
		  done = self.graphic_advance(ds)
		  para sprintf("%.1f%% Complete", done*100)
	       end
	       stack(margin:20, width:-w) do
		  subtitle "Task:"
		  $task_name_field = stack { para "" }
		  animate do
		     $task_name_field.clear{ para $task }
		  end
	       end
	    end
	    MiGA.RESET_STATUS
	 end
      end

      # Project report window
      def report
	 stack do
	    title $project.metadata[:name], align:"center"
	    $done = 0.0
	    $me = self
	    flow do
	       w = 40+30*Dataset.PREPROCESSING_TASKS.size
	       stack(margin:20, width:w) do
		  subtitle "Dataset tasks advance:"
		  shape do
		     $project.each_dataset do |ds|
			$done += $me.graphic_advance(ds, 1)
		     end
		  end
		  $done /= $project.metadata[:datasets].size
		  para sprintf("%.1f%% Complete", $done*100)
	       end
	       stack(margin:20, width:-w) do
		  subtitle "Task:"
		  $task_name_field = stack { para "" }
		  subtitle "Dataset:"
		  $dataset_name_field = stack { para "" }
		  animate do
		     $task_name_field.clear{ para $task }
		     $dataset_name_field.clear{ para $dataset }
		  end
	       end
	    end
	    if $done==1.0
	       stack(margin:20) do
		  subtitle "Project-wide tasks:"
		  Project.DISTANCE_TASKS.each { |t| para strong(t), ": ", ($project.add_result(t).nil? ? "Pending" : "Done") }
		  if $project.metadata[:type]==:clade
		     Project.INCLADE_TASKS.each { |t| para strong(t), ": ", ($project.add_result(t).nil? ? "Pending" : "Done") }
		  end
	       end
	    end
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

      def graphic_advance(ds, h=10)
	 ds_adv = ds.profile_advance
	 flow(width:30*Dataset.PREPROCESSING_TASKS.size) do
	    nostroke
	    i = 0
	    col = ["#CCC", rgb(119,130,61), rgb(160,41,50)]
	    ds_adv.each do |j|
	       stack(width:28,margin:0,top:0,left:i*30,height:h) do
		  background col[j]
		  t = Dataset.PREPROCESSING_TASKS[i]
		  hover do
		     $task = t
		     $dataset = ds.name
		  end
	       end
	       i += 1
	    end
	    nofill
	 end
	 return 0.0 if ds_adv.count{|i| i>0}==0
	 ds_adv.count{|i| i==1}.to_f/ds_adv.count{|i| i>0}
      end # graphic_advance

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
      def list_datasets ; GUI.init{ visit '/datasets' } ; end # list_datasets
      def process_report ; GUI.init{ visit '/report' } ; end # process_report
   end
end

