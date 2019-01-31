#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require 'miga/tax_index'
require 'zlib'
require 'tmpdir'

o = {q: true, format: :json}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt_filter_datasets(opt, o)
  opt.on('-i', '--index FILE',
    'Pre-calculated tax-index (in tabular format) to be used.',
    'If passed, dataset filtering arguments are ignored.'
    ){ |v| o[:index] = v }
  opt_common(opt, o)
end.parse!

##=> Functions <=
# Returns the _cannonical_ ID between strings +a+ and +b+.
def cannid(a, b) ; (a > b ? [b, a] : [a, b]).join('-') ; end

##=> Main <=
opt_require(o, project: '-P')

$stderr.puts 'Loading project.' unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

metric = p.is_clade? ? 'ani' : 'aai'
res_n  = "#{metric}_distances"
$stderr.puts "Reading distances (1-#{metric.upcase})." unless o[:q]
res = p.result res_n
raise "#{res_n} not yet calculated." if res.nil?
matrix = res.file_path(:matrix)
raise "#{res_n} has no matrix." if matrix.nil?
dist = {}
mfh = matrix =~ /\.gz$/ ? Zlib::GzipReader.open(matrix) : File.open(matrix, 'r')
mfh.each_line do |ln|
  next if mfh.lineno==1
  row = ln.chomp.split("\t")
  dist[cannid(row[1], row[2])] = [row[3], row[5], row[6], 0, ['root:biota']]
  $stderr.print("  Ln:#{mfh.lineno} \r") if !o[:q] and (mfh.lineno % 1_000) == 0
end
$stderr.puts "  Lines: #{mfh.lineno}" unless o[:q]
mfh.close

Dir.mktmpdir do |dir|
  if o[:index].nil?
    $stderr.puts 'Loading datasets.' unless o[:q]
    ds = p.datasets
    ds.select!{ |d| not d.metadata[:tax].nil? }
    ds = filter_datasets!(ds, o)
    
    $stderr.puts 'Indexing taxonomy.' unless o[:q]
    tax_index = MiGA::TaxIndex.new
    ds.each { |d| tax_index << d }
    tab = File.expand_path('index.tab', dir)
    File.open(tab, 'w') { |fh| fh.print tax_index.to_tab }
  else
    tab = o[:index]
  end

  $stderr.puts 'Traversing taxonomy.' unless o[:q]
  rank_i = 0
  MiGA::Taxonomy.KNOWN_RANKS.each do |rank|
    $stderr.print "o #{rank}: " unless o[:q]
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
    $stderr.puts "#{rank_n} pairs of datasets." unless o[:q]
  end
end

$stderr.puts 'Generating report.' unless o[:q]
dist.keys.each do |k|
  dist[k][5] = dist[k][4].join(' ')
  dist[k][4] = dist[k][4].first
  puts (k.split('-') + dist[k]).join("\t")
end

