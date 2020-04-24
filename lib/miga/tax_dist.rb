# @package MiGA
# @license Artistic-2.0

require 'miga/common'
require 'miga/taxonomy'
require 'zlib'

##
# Methods for taxonomy identification based on AAI/ANI values.
module MiGA::TaxDist
  # Class-level
  class << self

    ##
    # Absolute path to the :intax or :novel data file (determined by +test+) for
    # AAI, determined for options +opts+. Supported options:
    # - +:engine+: The search engine for AAI: +:blast+ (default) or +:diamond+
    def aai_path(test, opts = {})
      opts[:engine] ||= :blast
      engine = opts[:engine].to_s.downcase.to_sym
      test = test.to_s.downcase.to_sym
      return nil unless %i[intax novel].include? test
      engine = :blast if %i[blast+ blat].include? engine
      return nil unless %i[blast diamond].include? engine
      File.expand_path("../_data/aai-#{test}-#{engine}.tsv.gz", __FILE__)
    end

    ##
    # Returns a Hash, where the keys correspond to the taxonomic level
    # (see MiGA::Taxonomy.LONG_RANKS for the meanings), and the values
    # correspond to the p-values of +test+ (one of +:intax+ or +:novel+)
    # with options +opts+. See +aai_path+ for supported options.
    def aai_pvalues(aai, test, opts = {})
      y = {}
      Zlib::GzipReader.open(aai_path(test, opts)) do |fh|
        keys = nil
        fh.each_line do |ln|
          row = ln.chomp.split(/\t/)
          if fh.lineno == 1
            keys = row[1, row.size - 1].map(&:to_i)
          elsif row.shift.to_f >= aai
            vals = {}
            keys.each do |i|
              v = row.shift
              next if v == 'NA' # <- missing data
              rank = i.zero? ? :root : MiGA::Taxonomy.KNOWN_RANKS[i]
              vals[rank] = v.to_f
            end
            y = vals
            break
          end
        end
        fh.rewind # to avoid warnings caused by the break above
      end
      y
    end

    ##
    # Determines the degree to which a Float +aai+ value indicates similar
    # taxonomy (with +test+ :intax) or a novel taxon (with +test+ :novel) with
    # options +opts+. See +aai_path+ for supported options.
    # Returns a Hash with "likelihood" phrases as keys and values as an array
    # with cannonical rank (as in MiGA::Taxonomy) and estimated p-value.
    def aai_taxtest(aai, test, opts = {})
      meaning = {
        most_likely:   [0.00, 0.01],
        probably:      [0.01, 0.10],
        possibly_even: [0.10, 0.50]
      }
      pvalues = aai_pvalues(aai, test, opts)
      out = {}
      meaning.each do |phrase, thresholds|
        lwr, upr = thresholds
        min = pvalues.values.select { |v| v < upr }.max
        return out if min.nil?
        if min >= lwr
          v = pvalues.select { |_, vj| vj == min }
          out[phrase] = (test == :intax ? v.reverse_each : v).first
        end
      end
      out
    end
  end
end
