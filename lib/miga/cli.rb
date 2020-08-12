# @package MiGA
# @license Artistic-2.0

require 'miga/project'
require 'optparse'

##
# MiGA Command Line Interface API.
class MiGA::Cli < MiGA::MiGA
  require 'miga/cli/base'
  require 'miga/cli/opt_helper'
  require 'miga/cli/objects_helper'
  require 'miga/cli/action'
  include MiGA::Cli::OptHelper
  include MiGA::Cli::ObjectsHelper

  ##
  # Task to execute, a symbol
  attr_accessor :task

  ##
  # The CLI parameters (except the task), and Array of String
  attr_accessor :argv

  ##
  # Action to launch, an object inheriting from MiGA::Cli::Action
  attr_accessor :action

  ##
  # If files are expected after the parameters, a boolean
  attr_accessor :expect_files

  ##
  # Files passed after all other options, if +#expect_files = true+
  attr_accessor :files

  ##
  # If an operation verb preceding all other arguments is to be expected
  attr_accessor :expect_operation

  ##
  # Interactivity with the user is expected
  attr_accessor :interactive

  ##
  # Operation preceding all other options, if +#expect_operation = true+
  attr_accessor :operation

  ##
  # Include common options, a boolean (true by default)
  attr_writer :opt_common

  ##
  # Default values as a Hash
  attr_accessor :defaults

  ##
  # Parsed values as a Hash
  attr_reader :data

  def initialize(argv)
    @data = {}
    @defaults = { verbose: false, tabular: false }
    @opt_common = true
    @objects = {}
    if argv[0].nil? or argv[0].to_s[0] == '-'
      @task = :generic
    else
      @task = argv.shift.to_sym
      @task = @@TASK_ALIAS[task] unless @@TASK_ALIAS[task].nil?
    end
    @argv = argv
    reset_action
  end

  ##
  # Print +par+, ensuring new line at the end.
  # If the first parameter is +IO+, the output is sent there,
  # otherwise it's sent to +$stdout+
  def puts(*par)
    io = par.first.is_a?(IO) ? par.shift : $stdout
    io.puts(*par)
  end

  ##
  # Print +par+.
  # If the first parameter is +IO+, the output is sent there,
  # otherwise it's sent to +$stdout+
  def print(*par)
    io = par.first.is_a?(IO) ? par.shift : $stdout
    io.print(*par)
  end

  ##
  # Display a table with headers +header+ and contents +values+, both Array.
  # The output is printed to +io+
  def table(header, values, io = $stdout)
    self.puts(io, MiGA.tabulate(header, values, self[:tabular]))
  end

  ##
  # Print +par+ ensuring new line at the end, iff --verbose.
  # Date/time each line.
  # If the first parameter is +IO+, the output is sent there,
  # otherwise it's sent to +$stderr+
  def say(*par)
    return unless self[:verbose]

    super(*par)
  end

  ##
  # Same as MiGA::MiGA#advance, but checks if the CLI is verbose
  def advance(*par)
    super(*par) if self[:verbose]
  end

  ##
  # Ask a question +question+ to the user (requires +#interactive = true+)
  # The +default+ is used if the answer is empty
  # The +answers+ are supported values, unless nil
  # If --auto, all questions are anwered with +default+ unless +force+
  def ask_user(question, default = nil, answers = nil, force = false)
    ans = " (#{answers.join(' / ')})" unless answers.nil?
    dft = " [#{default}]" unless default.nil?
    print "#{question}#{ans}#{dft} > "
    if self[:auto] && !force
      puts ''
    else
      y = gets.chomp
    end
    y = default.to_s if y.nil? or y.empty?
    unless answers.nil? or answers.map(&:to_s).include?(y)
      warn "Answer not recognized: '#{y}'"
      return ask_user(question, default, answers, force)
    end
    y
  end

  ##
  # Set default values in the Hash +hsh+
  def defaults=(hsh)
    hsh.each { |k, v| @defaults[k] = v }
  end

  ##
  # Access parsed data
  def [](k)
    k = k.to_sym
    @data[k].nil? ? @defaults[k] : @data[k]
  end

  ##
  # Set parsed data
  def []=(k, v)
    @data[k.to_sym] = v
  end

  ##
  # Redefine #action based on #task
  def reset_action
    @action = nil
    if @@EXECS.include? task
      @action = Action.load(task, self)
    else
      warn "No action set for #{task}"
    end
  end

  ##
  # Perform the task requested (see #task); if +abort_on_error+, abort on
  # error
  def launch(abort_on_error = false)
    begin
      raise "See `miga -h`" if action.nil?

      action.launch
    rescue => err
      $stderr.puts "Exception: #{err}"
      $stderr.puts ''
      err.backtrace.each { |l| $stderr.puts "DEBUG: #{l}" }
      abort if abort_on_error
      err
    end
  end

  ##
  # Parse the #argv parameters
  def parse(&fun)
    if expect_operation
      @operation = @argv.shift unless argv.first =~ /^-/
    end
    OptionParser.new do |opt|
      banner(opt)
      fun[opt]
      opt_common(opt)
    end.parse!(@argv)
    if expect_files
      @files = argv
    end
  end

  ##
  # Ensure that these parameters have been passed to the CLI, as defined by
  # +par+, a Hash with object names as keys and parameter flag as values.
  # If missing, raise an error with message +msg+
  def ensure_par(req, msg = '%<name>s is mandatory: please provide %<flag>s')
    req.each do |k, v|
      raise (msg % { name: k, flag: v }) if self[k].nil?
    end
  end

  ##
  # Ensure that "type" is passed and valid for the given +klass+
  def ensure_type(klass)
    ensure_par(type: '-t')
    if klass.KNOWN_TYPES[self[:type]].nil?
      raise "Unrecognized type: #{self[:type]}"
    end
  end

  ##
  # Task description
  def task_description
    @@TASK_DESC[task]
  end
end
