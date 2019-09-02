# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'miga/tax_index'
require 'zlib'
require 'tmpdir'

class MiGA::Cli::Action::TaxDist < MiGA::Cli::Action

  def parse_cli
    cli.parse do |opt|
      cli.opt_object(opt, [:project])
      cli.opt_filter_datasets(opt)
      opt.on(
        '-i', '--index FILE',
        'Pre-calculated tax-index (in tabular format) to be used',
        'If passed, dataset filtering arguments are ignored'
        ){ |v| cli[:index] = v }
    end
  end

  def cannid(a, b)
    (a > b ? [b, a] : [a, b]).join('-')
  end

  def perform
    p = cli.load_project
    metric = p.is_clade? ? 'ani' : 'aai'
    res_n  = "#{metric}_distances"
    cli.say "Reading distances: 1-#{metric.upcase}"
    res = p.result(res_n)
    raise "#{res_n} not yet calculated" if res.nil?
    matrix = res.file_path(:matrix)
    raise "#{res_n} has no matrix" if matrix.nil?
    dist = {}
    mfh = (matrix =~ /\.gz$/) ?
      Zlib::GzipReader.open(matrix) : File.open(matrix, 'r')
    mfh.each_line do |ln|
      next if mfh.lineno == 1
      row = ln.chomp.split("\t")
      dist[cannid(row[1], row[2])] = [row[3], row[5], row[6], 0, ['root:biota']]
      cli.advance("Ln: #{mfh.lineno}") if (mfh.lineno % 1_000) == 0
    end
    cli.say "  Lines: #{mfh.lineno}"
    mfh.close

    Dir.mktmpdir do |dir|
      if cli[:index].nil?
        ds = cli.load_and_filter_datasets
        ds.keep_if { |d| !d.metadata[:tax].nil? }

        cli.say 'Indexing taxonomy'
        tax_index = TaxIndex.new
        ds.each { |d| tax_index << d }
        tab = File.expand_path('index.tab', dir)
        File.open(tab, 'w') { |fh| fh.print tax_index.to_tab }
      else
        tab = cli[:index]
      end

      cli.say 'Traversing taxonomy'
      rank_i = 0
      Taxonomy.KNOWN_RANKS.each do |rank|
        cli.say "o #{rank}: "
        rank_n = 0
        rank_i += 1
        in_rank = nil
        ds_name = []
        File.open(tab, 'r') do |fh|
          fh.each_line do |ln|
            if ln =~ /^ {#{(rank_i-1)*2}}\S+:\S+:/
              in_rank = nil
              ds_name = []
            elsif ln =~ /^ {#{rank_i*2}}(#{rank}:(\S+)):/
              in_rank = $2 == '?' ? nil : $1
              ds_name = []
            elsif ln =~ /^ *# (\S+)/ and not in_rank.nil?
              ds_i = $1
              ds_name << ds_i
              ds_name.each do |ds_j|
                k = cannid(ds_i, ds_j)
                next if dist[k].nil?
                rank_n += 1
                dist[k][3] = rank_i
                dist[k][4].unshift in_rank
              end
            end
          end
        end
        cli.say "#{rank_n} pairs of datasets"
      end
    end

    cli.say 'Generating report'
    dist.keys.each do |k|
      dist[k][5] = dist[k][4].reverse.join(' ')
      dist[k][4] = dist[k][4].first
      puts (k.split('-') + dist[k]).join("\t")
    end
  end
end
