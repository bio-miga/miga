
require 'date'

##
# High-level minimal requirements for the MiGA::MiGA class.
module MiGA

  ##
  # Current version of MiGA. An Array with three values:
  # - Float representing the major.minor version.
  # - Integer representing gem releases of the current version.
  # - Integer representing minor changes that require new version number.
  VERSION = [0.5, 7, 1]

  ##
  # Nickname for the current major.minor version.
  VERSION_NAME = 'collotype'

  ##
  # Date of the current gem release.
  VERSION_DATE = Date.new(2020, 2, 8)

  ##
  # Reference of MiGA.
  CITATION = 'Rodriguez-R et al (2018). ' \
    'The Microbial Genomes Atlas (MiGA) webserver: taxonomic and gene ' \
    'diversity analysis of Archaea and Bacteria at the whole genome level. ' \
    'Nucleic Acids Research 46(W1):W282-W288. doi:10.1093/nar/gky467.'

end

class MiGA::MiGA

  include MiGA

  ##
  # Major.minor version as Float.
  def self.VERSION ; VERSION[0] ; end

  ##
  # Complete version as string.
  def self.FULL_VERSION ; VERSION.join('.') ; end

  ##
  # Complete version with nickname and date as string.
  def self.LONG_VERSION
    "MiGA #{VERSION.join('.')} - #{VERSION_NAME} - #{VERSION_DATE}"
  end

  ##
  # Date of the current gem release.
  def self.VERSION_DATE ; VERSION_DATE ; end

  ##
  # Reference of MiGA.
  def self.CITATION ; CITATION ; end

end
