# @package MiGA
# @license artistic license 2.0

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
  $miga_path = File.expand_path("../../../", __FILE__)

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
    header("> " + $project.name.unmiga_name)
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
    header("> " + $project.name.unmiga_name)
    stack(margin:40) do
      para "#{$project.metadata[:datasets].size} datasets:"
      para ""
      $project.metadata[:datasets].each do |name|
        para "> ", link(name, :click=>"/dataset-#{name}")
      end
    end
    MiGA::GUI.reset_status
  end

  ##
  # Dataset details window.
  def dataset(name)
    stack(margin:40) do
      ds = $project.dataset(name)
      title ds.name.unmiga_name, align:"center"
      caption(link("Back to #{$project.name.unmiga_name} datasets",
        :click=>"/datasets"), align:"center")
      para ""
      stack{ ds.metadata.each { |k,v| para strong(k), ": ", v } }
      para ""
      flow do
        w = 40+30*MiGA::Dataset.PREPROCESSING_TASKS.size
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
      MiGA::GUI.reset_status
    end
  end

  ##
  # Project report window.
  def report
    stack(margin:40) do
      title $project.name.unmiga_name, align:"center"
      $done = 0.0
      $me = self
      flow do
        para ""
        w = 40+30*MiGA::Dataset.PREPROCESSING_TASKS.size
        stack(width:w) do
          para ""
          subtitle "Dataset tasks advance:"
          caption link("toggle"){ $adv_logo.toggle }
          para ""
          $adv_logo = stack do
            $project.each_dataset do |ds|
              $done += $me.graphic_advance(ds, 1)
            end
            motion do |_,y|
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
              MiGA::GUI.init{ visit "/dataset-#{$dataset}" } unless $dataset.nil?
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
          MiGA::Project.DISTANCE_TASKS.each do |t|
            para strong(t), ": ",
              ($project.add_result(t).nil? ? "Pending" : "Done")
          end
          if $project.metadata[:type]==:clade
            MiGA::Project.INCLADE_TASKS.each do |t|
              para strong(t), ": ",
                ($project.add_result(t).nil? ? "Pending" : "Done")
            end
          end
        end
      end
      para ""
      MiGA::GUI.reset_status
    end
  end

  private

    ##
    # Header in all windows
    def header(msg="")
      # workaround to shoes/shoes4#1212:
      $clicky ||= []
      $clicky.each{ |i| i.hide }
      $clicky = []
      
      keypress do |key|
        case key
        # Global
        when :control_o, :super_o
          open_project
        when :control_n, :super_n
          new_project
        when :control_d, :super_d
          new_dataset unless $project.nil?
        when :control_l, :super_l
          list_datasets unless $project.nil?
        when :control_r, :super_r
          progress_report unless $project.nil?
        end
      end
      
      flow(margin:[40,10,40,0]) do
        image $miga_path + "/gui/img/MiGA-sm.png"
        title msg
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
    
    def miga_blue(alpha=1.0)
      rgb(0,114,179,alpha)
    end

    def miga_red(alpha=1.0)
      rgb(179,0,3,alpha)
    end

      
    # =====================[ View : Elements ]
    
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
              image $miga_path + "/gui/img/#{img[k]}.png", margin: 2
              button(k.to_s.gsub("_"," ").capitalize, top:5){ send(k) }
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
          stack(width:50)
          $status_cont = stack(width:-300, height:1.0)
          every do
            $status_cont.clear { inscription MiGA::GUI.status, margin:5 }
          end
          stack(width:250, height:1.0) do
            inscription MiGA::MiGA.LONG_VERSION, align:"right", margin:5
          end
        end
        image $miga_path + "/gui/img/MiGA-sq.png",
          left:0, bottom:0, width:30, height:32
      end
    end

    ##
    # Display processing status of a dataset as a horizontal bar, as reported
    # by MiGA::Dataset#profile_advance.
    def graphic_advance(ds, h=10)
      ds_adv = ds.profile_advance
      flow(width:30*MiGA::Dataset.PREPROCESSING_TASKS.size) do
        nostroke
        i = 0
        col = ["#CCC", rgb(119,130,61), rgb(160,41,50)]
        ds_adv.each do |j|
          stack(width:28,margin:0,top:0,left:i*30,height:h) do
            background col[j]
            t = MiGA::Dataset.PREPROCESSING_TASKS[i]
            hover do
              $task = t
              $dataset = ds.name.unmiga_name
            end
          end
          i += 1
        end
        nofill
      end
      return 0.0 if ds_adv.count{|i| i>0} <= 1
      (ds_adv.count{|i| i==1}.to_f - 1.0)/(ds_adv.count{|i| i>0}.to_f - 1.0)
    end

    # =====================[ Controller : Projects ]

    ##
    # Load a project.
    def open_project
      MiGA::GUI.status = "Opening project..."
      MiGA::GUI.init do
        folder = ask_open_folder
        if folder.nil? or not MiGA::Project.exist? folder
          alert "Cannot find a MiGA project at #{folder}!" unless folder.nil?
        else
          $project = MiGA::Project.new folder
          visit "/project"
        end
      end
      MiGA::GUI.reset_status
    end
    
    ##
    # Create a project.
    def new_project
      MiGA::GUI.status = "Creating project..."
      MiGA::GUI.init do
        if MiGA::MiGA.initialized?
          folder = ask_save_folder
          if folder.nil? or MiGA::Project.exist? folder
            alert "Cannot overwrite existent MiGA project at #{folder}!" unless
              folder.nil?
          else
            $project = MiGA::Project.new folder
            visit "/project"
          end
        else
          alert "MiGA is currently uninitialized, no projects can be created."
        end
      end
      MiGA::GUI.reset_status
    end
    
    ##
    # Open a window on #datasets.
    def list_datasets
      MiGA::GUI.status = "Listing all datasets..."
      MiGA::GUI.init { visit "/datasets" }
      MiGA::GUI.reset_status
    end

    ##
    # Open a window on #report.
    def progress_report
      MiGA::GUI.status = "Creating progress report..."
      MiGA::GUI.init { visit "/report" }
      MiGA::GUI.reset_status
    end

  end
