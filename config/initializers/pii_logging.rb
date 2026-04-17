# frozen_string_literal: true

require 'pii_logging_formatter'

logger = Rails.logger
if logger.respond_to?(:formatter)
  logger.formatter = PiiLoggingFormatter.new(
    original_formatter: logger.formatter
  )
end
