# Narrowly filter known legacy-gem noise without changing behavior.

module Warning
  class << self
    alias_method :__warn_original, :warn

    def warn(msg)
      # 1) test-unit <-> assertions duplicate method warning
      return if msg.include?('method redefined; discarding old assert_raise_message')
      return if msg.include?('previous definition of assert_raise_message was here')

      # 2) simplecov 0.13 "literal string will be frozen in the future"
      # (emitted by simplecov/version.rb when assigning the VERSION constant)
      return if msg.include?('simplecov/version.rb') &&
                msg.include?('literal string will be frozen in the future')

      __warn_original(msg)
    end
  end
end
