# frozen_string_literal: true

require 'date'

##
# High-level minimal requirements for the MiGA::MiGA class.
module MiGA
  ##
  # Current version of MiGA. An Array with three values:
  # - Float representing the major.minor version.
  # - Integer representing gem releases of the current version.
  # - String indicating release status:
  #   - rc* release candidate, not released as gem
  #   - [0-9]+ stable release, released as gem
  VERSION = [1.3, 6, 2].freeze

  ##
  # Nickname for the current major.minor version.
  VERSION_NAME = 'mezzotint'

  ##
  # Date of the current gem relese.
  VERSION_DATE = Date.new(2023, 5, 18)

  ##
  # References of MiGA
  CITATION = []
  CITATION << <<~REF
    Rodriguez-R et al (2018). The Microbial Genomes Atlas (MiGA) webserver:
      taxonomic and gene diversity analysis of Archaea and Bacteria at the whole
      genome level. Nucleic Acids Research 46(W1):W282-W288.
      doi:10.1093/nar/gky467.
  REF
  CITATION << <<~REF
    Rodriguez-R et al (2020). Classifying prokaryotic genomes using the
      Microbial Genomes Atlas (MiGA) webserver. Bergey's Manual of Systematics
      of Archaea and Bacteria.
  REF
end

class MiGA::MiGA
  include MiGA

  ##
  # Major.minor version as Float
  def self.VERSION
    VERSION[0]
  end

  ##
  # Complete version as string
  def self.FULL_VERSION
    VERSION.join('.')
  end

  ##
  # Complete version with nickname and date as string
  def self.LONG_VERSION
    "MiGA #{VERSION.join('.')} - #{VERSION_NAME} - #{VERSION_DATE}"
  end

  ##
  # Date of the current gem release
  def self.VERSION_DATE
    VERSION_DATE
  end

  ##
  # Reference of MiGA
  def self.CITATION
    CITATION.map { |i| "- #{i}" }.join
  end

  def self.CITATION_ARRAY
    CITATION
  end
end
