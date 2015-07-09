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
	 stack(margin:40) do
	    title "Welcome to MiGA!", align:"center"
	    para ""
	    flow{ menu_bar [:open_project, :new_project, :help] }
	    para ""
	    stack do
	       image $miga_path + "/gui/img/MiGA-bg.png", width:150, height:50
	       para ""
	       para "If you use MiGA in your research, please consider citing:"
	       para MiGA.CITATION
	       para ""
	    end
	 end
	 MiGA.RESET_STATUS
	 keypress do |key|
	    if [:control_o, "o"].include? key
	       MiGA.STATUS = "Calling open_project..."
	       open_project
	    elsif [:control_n, "n"].include? key
	       MiGA.STATUS = "Calling new_project..."
	       new_project
	    end
	 end
      end

      # Project window
      def project
	 stack(margin:40) do
	    title $project.name.unmiga_name, align:"center"
	    caption $project.path, align:"center"
	    para ""
	    stack{ menu_bar [:list_datasets, :new_dataset, :progress_report, :help] }
	    para ""
	    stack do
	       para strong("Datasets"), ": ", $project.metadata[:datasets].size
	       $project.metadata.each { |k,v| para(strong(k), ": ", v) unless k==:datasets }
	    end
	    para ""
	 end
	 MiGA.RESET_STATUS
	 keypress do |key|
	    if [:control_r, "r"].include? key
	       MiGA.STATUS = "Calling progress_report..."
	       progress_report
	    elsif [:control_d, "d"].include? key
	       MiGA.STATUS = "Calling list_datasets..."
	       list_datasets
	    end
	 end
      end

      # Datasets list window
      def datasets
	 stack(margin:40) do
	    title $project.name.unmiga_name, align:"center"
	    caption $project.path, align:"center"
	    para ""
	    stack do
	       para "Displaying #{$project.metadata[:datasets].size} datasets:"
	       para ""
	       $project.metadata[:datasets].each do |name|
		  para link(name, :click=>"/dataset-#{name}")
	       end
	    end
	    para ""
	    MiGA.RESET_STATUS
	 end
      end

      # Dataset details window
      def dataset(name)
	 stack(margin:40) do
	    ds = $project.dataset(name)
	    title ds.name.unmiga_name, align:"center"
	    caption "A dataset in ", strong(link($project.name.unmiga_name, :click=>"/datasets")), align:"center"
	    para ""
	    stack{ ds.metadata.each { |k,v| para strong(k), ": ", v } }
	    para ""
	    flow do
	       w = 40+30*Dataset.PREPROCESSING_TASKS.size
	       stack(width:w) do
		  subtitle "Advance"
		  done = self.graphic_advance(ds)
		  para sprintf("%.1f%% Complete", done*100)
	       end
	       stack(width:-w) do
		  subtitle "Task"
		  $task_name_field = stack { para "" }
		  animate do
		     $task_name_field.clear{ para $task }
		  end
	       end
	    end
	    para ""
	    MiGA.RESET_STATUS
	 end
      end

      # Project report window
      def report
	 stack(margin:40) do
	    title $project.name.unmiga_name, align:"center"
	    $done = 0.0
	    $me = self
	    flow do
	       para ""
	       w = 40+30*Dataset.PREPROCESSING_TASKS.size
	       stack(width:w) do
		  para ""
		  subtitle "Dataset tasks advance:"
		  caption link("toggle"){ $adv_logo.toggle }
		  para ""
		  $adv_logo = stack do
		     $project.each_dataset do |ds|
			$done += $me.graphic_advance(ds, 1)
		     end
		     motion do |x,y|
			unless $task.nil?
			   $task_ds_box.clear do
			      subtitle "Task"
			      para $task
			      subtitle "Dataset"
			      para $dataset
			   end
			   $task_ds_box.show
			   $task_ds_box.move(w,y-150)
			end
		     end
		     click do
			GUI.init{ visit "/dataset-#{$dataset}" } unless $dataset.nil?
		     end
		     leave do
			$task = nil
			$dataset = nil
			$task_ds_box.hide
		     end
		  end
		  $done /= $project.metadata[:datasets].size
		  para sprintf("%.1f%% Complete", $done*100)
	       end
	       $task_ds_box = stack(width:-w)
	    end
	    if $done==1.0
	       para ""
	       stack do
		  subtitle "Project-wide tasks:"
		  Project.DISTANCE_TASKS.each { |t| para strong(t), ": ", ($project.add_result(t).nil? ? "Pending" : "Done") }
		  if $project.metadata[:type]==:clade
		     Project.INCLADE_TASKS.each { |t| para strong(t), ": ", ($project.add_result(t).nil? ? "Pending" : "Done") }
		  end
	       end
	    end
	    para ""
	    MiGA.RESET_STATUS
	 end
      end
      
      # =====================[ View : Elements ]
      # Menu bar
      def menu_bar actions
	 flow do
	    b = {
	       open_project:["Open project", "iconmonstr-archive-5-icon-256"],
	       new_project:["New project","iconmonstr-plus-5-icon-256"],
	       list_datasets:["List datasets", "iconmonstr-note-10-icon-256"],
	       new_dataset:["New dataset", "iconmonstr-note-25-icon-256"],
	       progress_report:["Progress report", "iconmonstr-bar-chart-2-icon-256"],
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
		     $dataset = ds.name.unmiga_name
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
	       visit "/project"
	    end
	 end
      end # new_project
      def list_datasets ; GUI.init{ visit "/datasets" } ; end # list_datasets
      def progress_report ; GUI.init{ visit "/report" } ; end # progress_report
   end
end

