require 'miga/result/base'

##
# Helper module including functions for results to handle software versions
module MiGA::Result::Versions
  ##
  # Add version information for the Software used by this result
  def add_versions(versions)
    versions.each { |k, v| self[:versions][k] = v }
  end

  ##
  # Get list of software and their versions as raw text (Markdown)
  def versions_md
    versions.map { |k, v| "- #{k}: #{v}" }.join("\n")
  end
end
