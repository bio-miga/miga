# frozen_string_literal: true

##
# Helper module including specific functions to handle objects that
# have configurable options. The class including this module must implement
# the methods +.OPTIONS+, +#metadata+, and +#save+.
module MiGA::Common::WithOption
  def option(key)
    assert_has_option(key)
    opt = option_by_metadata(key)
    value = opt.nil? ? option_by_default(key) : opt
    value = value[self] if value.is_a?(Proc)
    value
  end

  def set_option(key, value, from_string = false)
    metadata[key] = assert_valid_option_value(key, value, from_string)
    save
    option(key)
  end

  def all_options
    Hash[self.class.OPTIONS.each_key.map { |key| [key, option(key)] }]
  end

  def option?(key)
    !self.class.OPTIONS[key.to_sym].nil?
  end

  def option_by_metadata(key)
    metadata[key]
  end

  def option_by_default(key)
    self.class.OPTIONS[key.to_sym][:default]
  end

  def assert_has_option(key)
    opt = self.class.OPTIONS[key.to_sym]
    raise "Unrecognized option: #{key}" if opt.nil?
    opt
  end

  def assert_valid_option_value(key, value, from_string = false)
    opt = assert_has_option(key)
    value = option_from_string(key, value) if from_string

    # nil is always valid, and so are supported tokens
    return value if value.nil? || opt[:tokens]&.include?(value)

    if opt[:type] && !value.is_a?(opt[:type])
      raise "Invalid value type for #{key}: #{value.class}, not #{opt[:type]}"
    end

    if opt[:in] && !opt[:in].include?(value)
      raise "Value out of range for #{key}: #{value}, not in #{opt[:in]}"
    end

    value
  end

  def option_from_string(key, value)
    opt = assert_has_option(key)

    if ['', 'nil'].include?(value)
      nil
    elsif opt[:tokens]&.include?(value)
      value
    elsif opt[:type]&.equal?(Float)
      raise "Not a float: #{value}" unless value =~ /^-?\.?\d/
      value.to_f
    elsif opt[:type]&.equal?(Integer)
      raise "Not an integer: #{value}" unless value =~ /^-?\d/
      value.to_i
    elsif opt[:in]&.include?(true) && value == 'true'
      true
    elsif opt[:in]&.include?(false) && value == 'false'
      false
    else
      value
    end
  end
end
