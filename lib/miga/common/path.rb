module MiGA::Common::Path
  ##
  # Root path to MiGA (as estimated from the location of the current file).
  def root_path
    File.expand_path('../../../..', __FILE__)
  end

  ##
  # Path to a script to be executed for +task+. Supported +opts+ are:
  # - +:miga+ Path to the MiGA home to use. If not passed, the home of the
  #   library is used).
  def script_path(task, opts = {})
    opts[:miga] ||= root_path
    File.expand_path("scripts/#{task}.bash", opts[:miga])
  end
end

##
# MiGA extensions to the File class.
class File
  ##
  # Method to transfer a file from +old_name+ to +new_name+, using a +method+
  # that can be one of :symlink for File#symlink, :hardlink for File#link, or
  # :copy for FileUtils#cp_r.
  def self.generic_transfer(old_name, new_name, method)
    return nil if exist? new_name

    if (method == :copy)
      FileUtils.cp_r(old_name, new_name)
    else
      method = :link if method == :hardlink
      File.send(method, old_name, new_name)
    end
  end
end
