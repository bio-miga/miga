# frozen_string_literal: true

require 'json'

##
# Taxonomic classifications in MiGA.
class MiGA::Json < MiGA::MiGA
  class << self
    ##
    # Default parsing options. Supported +opts+ keys:
    # - +:contents+: If true, the input is assumed to be the contents to parse,
    #   not the path to a JSON file.
    # - +:default+: A base to attach the parsed hash. A Hash or a String (path).
    # - +:additions+: If addition classes should be parsed. By default is false.
    # - +:symbolize+: If names should be symbolized. By default it's true if
    #   additions is false, or false otherwise. They can both be false, but an
    #   exception will be raised if both are true
    def default_opts(opts = {})
      opts[:contents] ||= false
      opts[:additions] ||= false
      opts[:symbolize] = !opts[:additions] if opts[:symbolize].nil?
      if opts[:additions] and opts[:symbolize]
        raise 'JSON additions are not supported with symbolized names'
      end

      opts
    end

    ##
    # Parse a JSON file in +path+ and return a hash. Optionally,
    # use +default+ as the base to attach the parsed hash. +default+
    # can be a Hash or a String (path). See +default_opts+ for supported
    # +opts+.
    def parse(path, opts = {})
      opts = default_opts(opts)

      # Read JSON
      cont = path
      12.times do
        cont = File.read(path)
        break unless cont.empty?
        sleep 1 # Wait up to 12 seconds for racing processes (iff empty file)
      end unless opts[:contents]
      raise "Empty descriptor: #{opts[:contents] ? "''" : path}" if cont.empty?

      # Parse JSON
      params = {
        symbolize_names: opts[:symbolize],
        create_additions: opts[:additions]
      }
      y = JSON.parse(cont, params)

      # Add defaults
      unless opts[:default].nil?
        opts[:default] = parse(opts[:default]) if opts[:default].is_a? String
        y.each { |k, v| opts[:default][k] = v }
        y = opts[:default]
      end

      # Return
      y
    end

    ##
    # Generates and returns prettyfied JSON to represent +obj+.
    # If +path+ is passed, it saves the JSON in that file.
    def generate(obj, path = nil)
      y = JSON.pretty_generate(obj)
      File.open(path, 'w') { |fh| fh.print y } unless path.nil?
      y
    end
  end
end
