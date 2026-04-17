# frozen_string_literal: true

require_relative 'pii'

#
# Wraps an existing Logger formatter to scrub PII from log messages
# before they reach STDOUT.
#
# Mirrors PlatformSdk::Logging::PiiFormatter but uses Rails 5-compatible
# ActionDispatch::Http::ParameterFilter.
#
class PiiLoggingFormatter
  attr_reader :original_formatter

  def initialize(original_formatter: nil)
    @original_formatter = original_formatter || ::Logger::Formatter.new
    @param_filter = ActionDispatch::Http::ParameterFilter.new(
      Pii::DEFAULT_FIELDS
    )
  end

  def call(severity, timestamp, progname, message)
    scrubbed = scrub_message(message)
    @original_formatter.call(severity, timestamp, progname, scrubbed)
  end

  def respond_to_missing?(method, include_private = false)
    @original_formatter.respond_to?(method, include_private) || super
  end

  def method_missing(method, *args, &block)
    if @original_formatter.respond_to?(method)
      @original_formatter.send(method, *args, &block)
    else
      super
    end
  end

  private

  def scrub_message(message)
    case message
    when Hash
      @param_filter.filter(message)
    when String
      Pii::PII_PATTERNS.reduce(message) do |msg, pattern|
        msg.gsub(pattern, Pii::FILTERED)
      end
    else
      message
    end
  end
end
