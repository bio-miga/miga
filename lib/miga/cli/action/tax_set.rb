# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::TaxSet < MiGA::Cli::Action
  def parse_cli
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
      opt.on(
        '-s', '--tax-string STRING',
        'String corresponding to the taxonomy of the dataset',
        'A space-delimited set of \'rank:name\' pairs'
      ) { |v| cli[:taxstring] = v }
      opt.on(
        '-t', '--tax-file PATH',
        '(Mandatory unless -D and -s are provided)',
        'Tab-delimited file containing datasets taxonomy',
        'Each row corresponds to a datasets and each column to a rank',
        'The first row must be a header with the rank names,',
        'and the first column must contain dataset names'
      ) { |v| cli[:taxfile] = v }
    end
  end

  def perform
    p = cli.load_project
    if !cli[:taxfile].nil?
      cli.say 'Reading tax-file and registering taxonomy'
      tfh = File.open(cli[:taxfile], 'r')
      header = nil
      tfh.each_line do |ln|
        next if ln =~ /^\s*?$/

        r = ln.chomp.split(/\t/, -1)
        dn = r.shift
        if header.nil?
          header = r
          next
        end
        d = p.dataset(dn)
        if d.nil?
          warn "Impossible to find dataset at line #{$.}: #{dn}. Ignoring..."
          next
        end
        d.metadata[:tax] = Taxonomy.new(r, header)
        d.save
        cli.say "o #{d.name} registered"
      end
      tfh.close
    else
      cli.ensure_par({ dataset: '-D', taxstring: '-s' },
                     '%<flag>s is mandatory unless -t is provided')
      cli.say 'Registering taxonomy'
      d = cli.load_dataset
      d.metadata[:tax] = Taxonomy.new(cli[:taxstring])
      d.save
    end
  end
end
