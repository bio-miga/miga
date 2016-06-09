# @package MiGA
# @license Artistic-2.0

require "miga/common"
require "miga/taxonomy"
require "zlib"

##
# Methods for taxonomy identification based on AAI/ANI values.
module MiGA::TaxDist
  
  ##
  # Absolute path to the :intax or :novel data file (determined by +test+) for
  # AAI.
  def self.aai_path(test)
    test = test.downcase.to_sym
    return nil unless [:intax, :novel].include? test
    File.expand_path("../_data/aai-#{test}.tsv.gz", __FILE__)
  end

  # Returns a Hash, where the keys correspond to the taxonomic level
  # (see MiGA::Taxonomy.LONG_RANKS for the meanings), and the values correspond
  # to the p-values of being :intax or :novel, as determined by +test+.
  def self.aai_pvalues(aai, test)
    Zlib::GzipReader.open(aai_path(test)) do |fh|
      keys = nil
      fh.each_line do |ln|
        row = ln.chomp.split /\t/
        if fh.lineno==1
          keys = row[1, row.size-1].map{ |i| i.to_i }
        elsif row.shift.to_f >= aai
          vals = {}
          keys.each do |i|
            v = row.shift
            next if v=="NA"
            vals[MiGA::Taxonomy.KNOWN_RANKS[i]] = v.to_f
          end
          return vals
        end
      end # each_line ln
    end # open fh
    {}
  end

  # Determines the degree to which a Float +aai+ value indicates similar
  # taxonomy (with +test+ :intax) or a novel taxon (with +test+ :novel). Returns
  # a Hash with "likelihood" phrases as keys and values as an array with
  # cannonical rank (as in MiGA::Taxonomy) and estimated p-value.
  def self.aai_taxtest(aai, test)
    meaning = {most_likely:[0,0.01],probably:[0.01,0.1],possibly_even:[0.1,0.5]}
    pv = aai_pvalues(aai, test)
    out = {}
    meaning.each do |phrase, thresholds|
      lwr, upr = thresholds
      min = pv.values.select{ |v| v >= lwr }.min
      return out if min.nil?
      if min < upr
        v = pv.select{ |_,v| v==min }
        out[phrase] = (test==:intax ? v.reverse_each : v).first
      end
    end
    out
  end

end
