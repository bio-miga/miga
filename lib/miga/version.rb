require "date"

module MiGA
  
  VERSION = [0.2, 0, 7]
  
  VERSION_NAME = "pochoir"
  
  VERSION_DATE = Date.new(2016, 03, 25)
  
  CITATION = "Rodriguez-R et al, in preparation. Microbial Genomes Atlas: " +
    "Standardizing genomic and metagenomic analyses for Archaea and Bacteria."

end

class MiGA::MiGA
  
  include MiGA
  
  def self.VERSION ; VERSION[0] ; end
  
  def self.FULL_VERSION ; VERSION.join(".") ; end
  
  def self.LONG_VERSION
    "MiGA " + VERSION.join(".") + " - " + VERSION_NAME + " - " +
      VERSION_DATE.to_s
  end
  
  def self.VERSION_DATE ; VERSION_DATE ; end
  
  def self.CITATION ; CITATION ; end

end
