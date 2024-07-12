require 'shellwords'

##
# General functions for process (system call) execution
module MiGA::Common::SystemCall
  ##
  # Execute the command +cmd+ with options +opts+ determined by #run_cmd_opts
  #
  # The command +cmd+ can be:
  # - String: The command is processed as is, without changes
  # - Array: The command is built with +shelljoin+ so each value is escaped
  def run_cmd(cmd, opts = {})
    opts = run_cmd_opts(opts)
    cmd = cmd.shelljoin if cmd.is_a?(Array)
    spawn_opts = {}
    spawn_opts[:out] = opts[:stdout] if opts[:stdout]
    spawn_opts[:err] = opts[:stderr] if opts[:stderr]
    out_io, spawn_opts[:out] = IO.pipe if opts[:return] == :output
    spawn_opts[:err] = [:child, :out] if opts[:err2out] && spawn_opts[:out]
    opts[:source] = MiGA::MiGA.rc_path if opts[:source] == :miga
    if opts[:source] == :miga_env
      cmd = "eval \"$(#{File.join(root_path, 'bin', 'miga').shellescape} env)\" && #{cmd}"
    elsif opts[:source] && File.exist?(opts[:source])
      cmd = ". #{opts[:source].shellescape} && #{cmd}"
    end

    DEBUG "CMD: #{cmd}"
    puts "CMD: #{cmd}" if opts[:show_cmd]
    return if opts[:dry]

    pid = nil
    error = nil
    begin
      pid = spawn(opts[:env], cmd, spawn_opts)
      Process.wait(pid)
    rescue => e
      error = e
    end
    status = $?

    if opts[:raise] && !status&.success?
      raise MiGA::SystemCallError.new(
        "Command failed with status " \
          "#{status&.exitstatus}#{' (core dump)' if status&.coredump?}:\n" \
          "#{error&.class}: #{error&.message}\n" \
          "OPT: #{opts}\n" \
          "CMD: #{cmd}"
      )
    end

    case opts[:return]
    when :status ; status
    when :pid    ; pid
    when :error  ; error
    when :output
      spawn_opts[:out].close
      output = out_io.read
      out_io.close
      output
    end
  end

  ##
  # Options for #run_cmd using a Hash +opts+ to modify defaults
  #
  # Supported keys (as Symbol) include:
  # - stdout: Redirect STDOUT to this file
  # - stderr: Redirect STDOUT to this file
  # - dry: Don't run, just send the command to debug (default: false)
  # - return: What should the function return, supported values are
  #   +:status+ (Process::Status, default), +:pid+ (Integer, process ID),
  #   +:error+ (Error if failed, nil otherwise), +:output+ (String,
  #   contents sent to STDOUT)
  # - raise: Raise an exception (MiGA::SystemCallError) in case of failure
  #   (default: true)
  # - show_cmd: Print command to the STDOUT (prefixed with CMD: ) to ease
  #   debugging (default: false)
  # - err2out: Redirect STDERR to STDOUT
  # - env: Environmental variables as a Hash, keys and values must be strings
  # - source: A file to be sourced before running, or the Symbol +:miga+ to
  #   source the MiGA configuration file, or the Symbol +:miga_env+ to run
  #   `eval $(miga env)` beforehand instead
  def run_cmd_opts(opts = {})
    {
      stdout: nil,
      stderr: nil,
      dry: false,
      return: :status,
      raise: true,
      show_cmd: false,
      err2out: false,
      env: {},
      source: nil
    }.merge(opts)
  end
end
