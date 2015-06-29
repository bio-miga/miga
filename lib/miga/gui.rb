#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jun-26-2015
#

require 'miga/project'
require 'shoes'
require 'shoes/swt'

Shoes::Swt.initialize_backend

module MiGA
   class GUI < Shoes
      attr_reader :project
      url '/', :index
      $miga_path = File.expand_path(File.dirname(__FILE__) + "/../../")
      
      # Main MiGA window
      def index
	 menu_bar
	 stack do
	    image $miga_path + "/gui/img/MiGA-bg.png", margin:10
	 end
	 status_bar
      end
      
      # Menu bar
      def menu_bar
	 flow(width:1.0) do
	    b = {
	       open_project:["Open project", "iconmonstr-archive-5-icon-256"],
	       new_project:["New project","iconmonstr-plus-5-icon-256"],
	       select_dataset:["Select dataset", "iconmonstr-note-10-icon-256"],
	       add_dataset:["Add dataset", "iconmonstr-note-25-icon-256"],
	       project_advance:["Project report", "iconmonstr-bar-chart-2-icon-256"]
	    }
	    b.each_pair do |k,v|
	       flow(margin:5, width:100) do
		  background "#EEE" .. "#AAA"
		  image $miga_path + "/gui/img/#{v[1]}.png", width:40, height:40, margin:8
		  inscription "#{v[0]}\n", align:"left", top:7
	       end
	    end
	 end
      end
      # Status bar
      def status_bar
	 stack(bottom:0) do
	    flow bottom:0, height:20, margin:0 do
	       background "#CCC"
	       stack(width:50)
	       stack(width:-300, height:1.0) do
		  $status = inscription "Initializing MiGA...", margin:5
	       end
	       stack(width:250, height:1.0) do
		  inscription MiGA.LONG_VERSION, align:"right", margin:5
	       end
	    end
	    @m = image $miga_path + "/gui/img/MiGA-sq.png", left:0, bottom:0, width:30, height:32
	 end
      end
   end
end

