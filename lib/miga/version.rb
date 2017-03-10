
require "date"

##
# High-level minimal requirements for the MiGA::MiGA class.
module MiGA
  
  ##
  # Current version of MiGA. An Array with three values:
  # - Float representing the major.minor version.
  # - Integer representing gem releases of the current version.
  # - Integer representing minor changes that require new version number.
  VERSION = [0.2, 2, 3]
  
  ##
  # Nickname for the current major.minor version.
  VERSION_NAME = "pochoir"
  
  ##
  # Date of the current gem release.
  VERSION_DATE = Date.new(2016, 8, 31)
  
  ##
  # Reference of MiGA.
  CITATION = "Rodriguez-R et al, in preparation. Microbial Genomes Atlas: " +
    "Standardizing genomic and metagenomic analyses for Archaea and Bacteria."

end

class MiGA::MiGA
  
  include MiGA
  
  ##
  # Major.minor version as Float.
  def self.VERSION ; VERSION[0] ; end

  ##
  # Complete version as string.
  def self.FULL_VERSION ; VERSION.join(".") ; end

  ##
  # Complete version with nickname and date as string.
  def self.LONG_VERSION
    "MiGA " + VERSION.join(".") + " - " + VERSION_NAME + " - " +
      VERSION_DATE.to_s
  end

  ##
  # Date of the current gem release.
  def self.VERSION_DATE ; VERSION_DATE ; end

  ##
  # Reference of MiGA.
  def self.CITATION ; CITATION ; end

end
