# frozen_string_literal: true

#
# Shared PII constants and regex patterns for FERPA/COPPA compliance purposes.
# Mirrors PlatformSdk::Pii module from strongmind-platform-sdk but implemented
# inline because canvas-lms cannot leverage the SDK (Rails 5 / Ruby 2.5).
#
# Used by both Sentry event scrubbing and stdout log message scrubbing.
#
module Pii
  DEFAULT_FIELDS = [
    :email, /\Aname\z/i, :first_name, :last_name, :student_name, :username,
    :phone, :phone_number, :address, :street, :city, :zip, :postal_code,
    :ssn, :social_security, :date_of_birth, :dob, :birthday,
    :ip_address, /\Aip\z/i, :remote_ip,
    :password, :password_confirmation, :token, :secret, :api_key,
    :authorization
  ].freeze

  FILTERED = '[FILTERED]'

  EMAIL_REGEX = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/
  SSN_REGEX = /\b\d{3}-\d{2}-\d{4}\b/
  PHONE_REGEX = /(?<!\d)(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/

  PII_PATTERNS = [EMAIL_REGEX, SSN_REGEX, PHONE_REGEX].freeze
end
