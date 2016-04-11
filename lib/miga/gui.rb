# @package MiGA
# @license Artistic-2.0

require "miga/project"
require "shoes"
require "shoes/swt"

Shoes::Swt.initialize_backend

##
# Graphical User Interface for MiGA using Shoes.
class MiGA::GUI < Shoes
  
  # Class-level
  
  ##
  # Set system status for MiGA::GUI.
  def self.status=(status) @@STATUS = status ; end

  ##
  # System status for MiGA::GUI.
  def self.status() @@STATUS; end
  @@STATUS = "Initializing MiGA..."

  ##
  # Reset the system status for MiGA::GUI.
  def self.reset_status() @@STATUS="MiGA is ready to go!" ; end

  url "/",		:index
  url "/project",	:project
  url "/datasets",	:datasets
  url "/dataset-(.*)",	:dataset
  url "/report",	:report
  $miga_gui_path = File.expand_path("../../../gui", __FILE__)

  ##
  # Initialize GUI.
  def self.init (&block)
    Shoes.app title: "MiGA | Microbial Genomes Atlas",
      width: 750, height: 400, &block
  end
  
  # =====================[ View : Windows ]
  
  ##
  # Main window.
  def index
    header("Microbial Genomes Atlas")
    stack(margin:40) do
      menu_bar [:open_project, :new_project, :help]
      box alpha: 0.0 do
        para "Welcome to the MiGA GUI. If you use MiGA in your research, ",
          "please consider citing:\n", MiGA::MiGA.CITATION
      end
    end
    MiGA::GUI.reset_status
    status_bar
  end

  ##
  # Project window.
  def project
    header("» " + $project.name.unmiga_name)
    stack(margin:40) do
      menu_bar [:list_datasets, :new_dataset, :progress_report, :help]
      stack(margin_top:10) do
        para strong("Path"), ": ", $project.path
        para strong("Datasets"), ": ", $project.metadata[:datasets].size
        $project.metadata.each do |k,v|
          para(strong(k.to_s.capitalize), ": ", v) unless k==:datasets
        end
      end
    end
    MiGA::GUI.reset_status
  end

  ##
  # Datasets list window.
  def datasets
    header("» " + $project.name.unmiga_name)
    stack(margin:40) do
      para "#{$project.metadata[:datasets].size} datasets:"
      para ""
      flow(width: 1.0) do
        $project.metadata[:datasets].each do |name|
          stack(width:150) do
            para "> ", link(name.unmiga_name){ show_dataset(name) }
          end
        end
      end
    end
    MiGA::GUI.reset_status
  end

  ##
  # Dataset details window.
  def dataset(name)
    header("» " + $project.name.unmiga_name + " » " + name.unmiga_name)
    stack(margin:40) do
      ds = $project.dataset(name)
      stack do
        ds.metadata.each { |k,v| para strong(k.to_s.capitalize), ": ", v }
      end
      flow(margin_top:10) do
        w = 40+30*MiGA::Dataset.PREPROCESSING_TASKS.size
        stack(width:w) do
          subtitle "Advance"
          done = graphic_advance(ds)
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
      MiGA::GUI.reset_status
    end
  end

  ##
  # Project report window.
  def report
    header("» " + $project.name.unmiga_name)
    stack(margin:40) do
      $done_para = subtitle "Dataset tasks advance: "
      $done = 0.0
      w = 40+30*MiGA::Dataset.PREPROCESSING_TASKS.size
      stack(width:w) do
        stack(margin_top:10) do
          $done = $project.datasets.map{ |ds| graphic_advance(ds, 7) }.inject(:+)
          motion { |_,y| show_report_hover(w, y) }
          click { show_dataset($dataset) }
        end
        $done /= $project.metadata[:datasets].size
        $done_para.text += sprintf("%.1f%% Complete.", $done*100)
      end
      $task_ds_box = stack(width:-w)
      stack(margin_top:10) do
        subtitle "Project-wide tasks:"
        tasks = MiGA::Project.DISTANCE_TASKS
        tasks += MiGA::Project.INCLADE_TASK if $project.metadata[:type]==:clade
        tasks.each do |t|
          para strong(t), ": ",
            ($project.add_result(t, false).nil? ? "Pending" : "Done")
        end
      end if $done==1.0
    end
  end

  private
    
    ##
    # The MiGA GUI's blue.
    def miga_blue(alpha=1.0)
      rgb(0,121,166,alpha)
    end

    ##
    # The MIGA GUI's red.
    def miga_red(alpha=1.0)
      rgb(179,0,3,alpha)
    end  

    # =====================[ View : Elements ]
    
    ##
    # Header in all windows
    def header(msg="")
      # workaround to shoes/shoes4#1212:
      $clicky ||= []
      $clicky.each{ |i| i.hide }
      $clicky = []
      # Keyboard support
      key_shortcuts = {
        :control_o => :open_project,    :super_o => :open_project,
        :control_n => :new_project,     :super_n => :new_project,
        :control_l => :list_datasets,   :super_l => :list_datasets,
        :control_r => :progress_report, :super_r => :progress_report
      }
      keypress do |key|
        funct = key_shortcuts[key]
        send(funct) unless funct.nil?
      end
      # Graphical header
      flow(margin:[40,10,40,0]) do
        image $miga_gui_path + "/img/MiGA-sm.png", width: 120, height: 50
        title msg, margin_top: 5, margin_left: 5
      end
    end

    ##
    # General-purpose box
    def box(opts={}, &blk)
      flow(margin_bottom:5) do
        opts[:alpha] ||= 0.2
        opts[:side_line] ||= miga_blue
        opts[:background] ||= miga_blue(opts[:alpha])
        stack(width: 5, height: 1.0) do
          background opts[:side_line]
        end unless opts[:right]
        stack(width: -5) do
          background opts[:background]
          stack{ background rgb(0,0,0,1.0) } # workaround to shoes/shoes4#1190
          s = stack(margin:5, &blk)
          unless opts[:click].nil?
            s.click{ visit opts[:click] }
          end
        end
        stack(width: 5, height: 1.0) do
          background opts[:side_line]
        end if opts[:right]
      end
    end
    
    ##
    # Menu bar.
    def menu_bar actions
      box do
        flow do
          img = {
            open_project: "iconmonstr-archive-5-icon-40",
            new_project: "iconmonstr-plus-5-icon-40",
            list_datasets: "iconmonstr-note-10-icon-40",
            new_dataset: "iconmonstr-note-25-icon-40",
            progress_report: "iconmonstr-bar-chart-2-icon-40",
            help: "iconmonstr-help-3-icon-40"}
          actions.each do |k|
            flow(margin:0, width:200) do
              image $miga_gui_path + "/img/#{img[k]}.png", margin: 2
              button(k.to_s.unmiga_name.capitalize, top:5){ send(k) }
            end
          end
        end
      end
    end
      
    ##
    # Status bar.
    def status_bar
      stack(bottom:0) do
        flow bottom:0, height:20, margin:0 do
          background "#CCC"
          $status_cont = stack(width:-300, height:1.0, margin_left:45)
          every do
            $status_cont.clear { inscription MiGA::GUI.status, margin:5 }
          end
          stack(width:250, height:1.0, right: 5) do
            inscription MiGA::MiGA.LONG_VERSION, align:"right", margin:5
          end
        end
        image "#{$miga_gui_path}/img/MiGA-sq.png",
          left:10, bottom:5, width:30, height:32
      end
    end

    ##
    # Display processing status of a dataset as a horizontal bar, as reported
    # by MiGA::Dataset#profile_advance.
    def graphic_advance(ds, h=10)
      ds_adv = ds.profile_advance
      flow(width:30*MiGA::Dataset.PREPROCESSING_TASKS.size) do
        nostroke
        col = ["#CCC", rgb(119,130,61), rgb(160,41,50)]
        ds_adv.each_index do |i|
          stack(width:28,margin:0,top:0,left:i*30,height:h) do
            background col[ ds_adv[i] ]
            t = MiGA::Dataset.PREPROCESSING_TASKS[i]
            hover do
              $task = t
              $dataset = ds.name.unmiga_name
            end
            leave do
              $task = nil
              $dataset = nil
              $task_ds_box.hide unless $task_ds_box.nil?
            end
          end
        end
        nofill
      end
      return 0.0 if ds_adv.count{|i| i>0} <= 1
      (ds_adv.count{|i| i==1}.to_f - 1.0)/(ds_adv.count{|i| i>0}.to_f - 1.0)
    end

    def show_report_hover(w, y)
      unless $task.nil?
        $task_ds_box.clear do
          para strong("Task: "), $task, "\n", strong("Dataset: "), $dataset
        end
        $task_ds_box.show
        $task_ds_box.move(w-20, y-115)
      end
    end

    # =====================[ Controller : Projects ]

    ##
    # Load a project.
    def open_project
      open_window("Opening project...") do
        folder = ask_open_folder
        if folder.nil? or not MiGA::Project.exist?(folder)
          alert "Cannot find a MiGA project at #{folder}!" unless folder.nil?
        else
          $project = MiGA::Project.new(folder)
          visit "/project"
        end
      end
    end
    
    ##
    # Create a project.
    def new_project
      open_window("Creating project...") do
        if MiGA::MiGA.initialized?
          folder = ask_save_folder
          if folder.nil? or MiGA::Project.exist?(folder)
            alert "Cannot overwrite existent MiGA project at #{folder}!" unless
              folder.nil?
          else
            $project = MiGA::Project.new(folder)
            visit "/project"
          end
        else
          # FIXME Add a way to initialize MiGA from the GUI
          alert "MiGA is currently uninitialized, no projects can be created."
        end
      end
    end
    
    ##
    # Open a window on #datasets.
    def list_datasets
      open_window("Listing all datasets..."){
        visit "/datasets" } unless $project.nil?
    end

    ##
    # Open a window on #dataset +name+.
    def show_dataset(name)
      open_window("Showing dataset details..."){
        visit "/dataset-#{name}" } unless name.nil?
    end

    ##
    # Open a window on #report.
    def progress_report
      open_window("Creating progress report..."){
        visit "/report" } unless $project.nil?
    end

    ##
    # Open a window sending +msg+ to the status, the yields +blk+.
    def open_window(msg, &blk)
      MiGA::GUI.status = msg
      MiGA::GUI.init(&blk)
      MiGA::GUI.reset_status
    end

end
