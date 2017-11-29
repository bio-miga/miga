# @package MiGA
# @license Artistic-2.0

##
# Helper module including specific functions handle plugins.
module MiGA::Project::Plugins

  ##
  # Installs the plugin in the specified path.
  def install_plugin(path)
    abs_path = File.absolute_path(path)
    raise "Plugin already installed in project: #{abs_path}." unless
      metadata[:plugins].nil? or not metadata[:plugins].include?(abs_path)
    raise "Malformed MiGA plugin: #{abs_path}." unless
      File.exist?(File.expand_path("miga-plugin.json", abs_path))
    self.metadata[:plugins] ||= []
    self.metadata[:plugins] << abs_path
    save
  end

  ##
  # Uninstall the plugin in the specified path.
  def uninstall_plugin(path)
    abs_path = File.absolute_path(path)
    raise "Plugin not currently installed: #{abs_path}." if
      metadata[:plugins].nil? or not metadata[:plugins].include?(abs_path)
    self.metadata[:plugins].delete(abs_path)
    save
  end

  ##
  # List plugins installed in the project.
  def plugins ; metadata[:plugins] ||= [] ; end

  ##
  # Loads the plugins installed in the project.
  def load_plugins
    plugins.each { |pl| require File.expand_path("lib-plugin.rb", pl) }
  end

end
