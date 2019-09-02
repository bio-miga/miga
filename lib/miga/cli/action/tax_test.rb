# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'miga/tax_dist'

class MiGA::Cli::Action::TaxTest < MiGA::Cli::Action

  def parse_cli
    cli.defaults = {test: 'both', ref_project: false}
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset])
      opt.on(
        '--ref-project',
        'Use the taxonomy from the reference project, not the current project'
        ){ |v| cli[:ref_project] = v }
      opt.on(
        '-t', '--test STRING',
        'Test to perform. Supported values: intax, novel, both'
        ){ |v| cli[:test] = v.downcase }
    end
  end

  def perform
    d = cli.load_dataset
    cli.say 'Finding closest relative'
    cr = d.closest_relatives(1, cli[:ref_project])
    if cr.nil? or cr.empty?
      raise 'Action not supported for the project or dataset' if cr.nil?
      raise 'No close relatives found'
    else
      cli.say 'Querying probability distributions'
      cr = cr[0]
      cli.puts "Closest relative: #{cr[0]} with AAI: #{cr[1]}."
      if self[:ref_project]
        if (ref = p.metadata[:ref_project]).nil?
          raise '--ref-project requested but no reference project has been set'
        end
        if (q = MiGA::Project.load(ref)).nil?
          raise '--ref-project requested but reference project doesn\'t exist'
        end
        cr_d = q.dataset(cr[0])
      else
        cr_d = p.dataset(cr[0])
      end
      tax = cr_d.metadata[:tax] unless cr_d.nil?
      tax ||= {}

      if %w[intax both].include? cli[:test]
        # Intax
        r = TaxDist.aai_pvalues(cr[1], :intax).map do |k,v|
          sig = ''
          [0.5, 0.1, 0.05, 0.01].each{ |i| sig << '*' if v<i }
          [Taxonomy.LONG_RANKS[k], (tax[k] || '?'), v, sig]
        end
        cli.puts ''
        cli.puts 'Taxonomic classification'
        cli.puts MiGA.tabulate(%w[Rank Taxonomy P-value Signif.], r)
      end

      if %w[novel both].include? cli[:test]
        # Novel
        r = TaxDist.aai_pvalues(cr[1], :novel).map do |k,v|
          sig = ''
          [0.5, 0.1, 0.05, 0.01].each{ |i| sig << '*' if v<i }
          [Taxonomy.LONG_RANKS[k], v, sig]
        end
        cli.puts ''
        cli.puts 'Taxonomic novelty'
        cli.puts MiGA.tabulate(%w[Rank P-value Signif.], r)
      end

      cli.puts ''
      cli.puts 'Significance at p-value below: *0.5, **0.1, ***0.05, ****0.01.'
    end
  end
end
