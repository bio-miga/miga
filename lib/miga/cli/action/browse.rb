# frozen_string_literal: true

require 'miga/cli/action'

# Action: miga browse
class MiGA::Cli::Action::Browse < MiGA::Cli::Action
  def parse_cli
    cli.parse do |opt|
      cli.defaults = { open: true }
      cli.opt_object(opt, [:project])
    end
  end

  def perform
    p = cli.load_project
    create_empty_page(p)
    generate_project_page(p)
    say 'Creating dataset pages'
    cli.load_project.each_dataset do |d|
      generate_dataset_page(p, d)
    end
    generate_datasets_index(p)
    say "Open in your browser: #{File.join(p.path, 'index.html')}"
  end

  private

  ##
  # Create an empty page with necessary assets for project +p+
  def create_empty_page(p)
    say 'Creating project page'
    FileUtils.mkdir_p(browse_file(p, '.'))
    %w[favicon-32.png style.css].each do |i|
      FileUtils.cp(template_file(i), browse_file(p, i))
    end
    write_file(p, 'about.html') do
      build_from_template('about.html', citation: MiGA::MiGA.CITATION)
    end
  end

  ##
  # Create landing page for project +p+
  def generate_project_page(p)
    # Redirect page
    write_file(p, '../index.html') { build_from_template('redirect.html') }

    # Summaries
    summaries = Dir["#{p.path}/*.tsv"].map do |i|
      b = File.basename(i, '.tsv')
      generate_summary_page(i, p)
      "<li><a href='s-#{b}.html'>#{format_name(b)}</a></li>"
    end.join('')

    # Project index page
    data = {
      project_active: 'active',
      information: format_metadata(p),
      summaries: summaries.empty? ? 'None' : "<ul>#{summaries}</ul>",
      results: format_results(p)
    }
    write_file(p, 'index.html') { build_from_template('index.html', data) }
  end

  ##
  # Create page for the summary +path+ in project +p+
  def generate_summary_page(path, p)
    b = File.basename(path, '.tsv')
    table = '<table class="table table-hover table-responsive">'
    File.open(path, 'r') do |fh|
      fh.each do |ln|
        r = ln.chomp.split("\t")
        if $. == 1
          table += '<thead><tr>' +
            r.map { |i| "<th scope=col>#{format_name(i)}</th>" }.join(' ') +
            '</tr></thead><tbody>'
        else
          table += "<tr><th scope=row>#{r.shift}</th>" +
            r.map { |i| "<td>#{i}</td>" }.join(' ') + "</tr>"
        end
      end
    end
    table += '</tbody></table>'
    write_file(p, "s-#{b}.html") do
      build_from_template(
        'summary.html', file: "#{b}.tsv", name: format_name(b), table: table
      )
    end
  end

  ##
  # Create page for dataset +d+ within project +p+
  def generate_dataset_page(p, d)
    data = {
      unmiga_name: d.name.unmiga_name,
      information: format_metadata(d),
      results: format_results(d)
    }
    write_file(p, "d_#{d.name}.html") do
      build_from_template('dataset.html', data)
    end
  end

  ##
  # Create pages for reference and query dataset indexes
  def generate_datasets_index(p)
    say 'Creating index pages'
    data = format_dataset_index(p)
    data.each do |k, v|
      write_file(p, "#{k}_datasets.html") do
        v[:list] = 'None' if v[:list] == ''
        build_from_template(
          'datasets.html',
          v.merge(:"#{k}_datasets_active" => 'active')
        )
      end
    end
  end

  def format_dataset_index(p)
    data = {
      ref: { type_name: 'Reference', list: '' },
      qry: { type_name: 'Query', list: '' }
    }
    p.each_dataset do |d|
      data[d.ref? ? :ref : :qry][:list] +=
        "<li><a href='d_#{d.name}.html'>#{d.name.unmiga_name}</a></li>"
    end
    data
  end

  ##
  # Format +obj+ metadata as a table
  def format_metadata(obj)
    '<table class="table table-sm table-responsive">' +
      obj.metadata.data.map do |k, v|
        case k
        when /^run_/, :plugins, :user
          next
        when :web_assembly_gz
          v = "<a href='#{v}'>#{v[0..50]}...</a>"
        when :datasets
          v = v.size
        end
        "<tr><td class='text-right pr-4'><b>#{format_name(k)}</b></td>" \
             "<td>#{v}</td></tr>"
      end.compact.join('') +
      '</table>'
  end

  ##
  # Format +obj+ results as cards
  def format_results(obj)
    o = ''
    obj.each_result do |key, res|
      links = format_result_links(res)
      stats = format_result_stats(res)
      next unless links || stats
      name = format_name(key)
      url_doc =
        'http://manual.microbial-genomes.org/part5/workflow#' +
        key.to_s.tr('_', '-')
      o += <<~CARD
        <div class="col-md-6 mb-4">
          <h3>#{name}</h3>
          <div class='border-left p-3'>
            #{stats}
            #{links}
          </div>
          <div class='border-top p-2 bg-light'>
            <a target=_blank href="#{url_doc}" class='p-2'>Learn more</a>
          </div>
        </div>
      CARD
    end
    "<div class='row'>#{o}</div>"
  end

  def format_name(str)
    str
      .to_s.unmiga_name
      .sub(/^./, &:upcase)
      .gsub(/(Aai|Ani|Ogs|Cds|Ssu| db$| ssu )/, &:upcase)
      .sub(/Haai/, 'hAAI')
      .sub(/Mytaxa/, 'MyTaxa')
      .sub(/ pvalue$/, ' p-value')
      .sub(/contigs$/, 'Contigs')
  end

  def format_result_links(res)
    links = []
    res.each_file do |key, _|
      name = format_name(key)
      links << "<a href='../#{res.file_path(key, true)}'>#{name}</a><br/>"
    end
    links.empty? ? nil : links.join('')
  end

  def format_result_stats(res)
    res.stats.map do |k, v|
      v = [v, ''] unless v.is_a? Array
      v[0] = ('%.3g' % v[0]) if v[0].is_a? Float
      "<b>#{format_name(k)}:</b> #{v[0]}#{v[1]}<br/>"
    end.join('') + '<br/>' unless res.stats.empty?
  end

  ##
  # Write +file+ within the browse folder of project +p+ using the passed
  # block output as content
  def write_file(p, file)
    File.open(browse_file(p, file), 'w') { |fh| fh.print yield }
  end

  ##
  # Use a +template+ file to generate content with a hash of +data+ over the
  # layout page if +layout+ is true
  def build_from_template(template, data = {}, layout = true)
    cont = File.read(template_file(template)).miga_variables(data)
    return cont unless layout

    build_from_template(
      'layout.html',
      data.merge(content: cont, project_name: cli.load_project.name),
      false
    )
  end

  ##
  # Path to the template browse file
  def template_file(file)
    File.join(
      MiGA::MiGA.root_path,
      'lib', 'miga', 'cli', 'action', 'browse', file
    )
  end

  ##
  # Path to the browse file in the project
  def browse_file(p, file)
    File.join(p.path, 'browse', file)
  end
end
