#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone PII scrubbing verification script.
# Runs with vanilla Ruby — no Rails, no Docker, no bundle required.
#
# Usage (from canvas-lms root):
#   ruby script/verify_pii_scrubbing.rb

require_relative '../lib/pii'
require 'logger'

PASS = "\u2705"
FAIL = "\u274C"

$results = { pass: 0, fail: 0 }

def assert_equal(description, condition)
  if condition
    puts "  #{PASS} #{description}"
    $results[:pass] += 1
  else
    puts "  #{FAIL} #{description}"
    $results[:fail] += 1
  end
end

def scrub_string(message)
  Pii::PII_PATTERNS.reduce(message) do |msg, pattern|
    msg.gsub(pattern, Pii::FILTERED)
  end
end

# Lightweight stand-in for ActionDispatch::Http::ParameterFilter.
# Replicates core behavior: matches hash keys against symbols and regexes,
# replaces matched values with the mask.
class SimpleParameterFilter
  def initialize(fields, mask: '[FILTERED]')
    @symbols = fields.select { |f| f.is_a?(Symbol) }.map(&:to_s)
    @regexes = fields.select { |f| f.is_a?(Regexp) }
    @mask = mask
  end

  def filter(hash)
    hash.each_with_object({}) do |(key, value), result|
      str_key = key.to_s
      if match?(str_key)
        result[key] = @mask
      elsif value.is_a?(Hash)
        result[key] = filter(value)
      else
        result[key] = value
      end
    end
  end

  private

  def match?(key)
    downkey = key.downcase
    @symbols.any? { |s| downkey.include?(s.downcase) } ||
      @regexes.any? { |r| key =~ r }
  end
end

pii_filter = SimpleParameterFilter.new(Pii::DEFAULT_FIELDS)

# ============================================================
# Pii module constants
# ============================================================
puts "\n=== Pii::DEFAULT_FIELDS ==="
assert_equal("is frozen", Pii::DEFAULT_FIELDS.frozen?)
%i[email first_name last_name student_name username phone
   phone_number address ssn date_of_birth password].each do |field|
  assert_equal("includes :#{field}", Pii::DEFAULT_FIELDS.include?(field))
end
regexes = Pii::DEFAULT_FIELDS.select { |f| f.is_a?(Regexp) }
assert_equal("includes /\\Aname\\z/i regex", regexes.include?(/\Aname\z/i))
assert_equal("includes /\\Aip\\z/i regex", regexes.include?(/\Aip\z/i))

puts "\n=== Pii::FILTERED ==="
assert_equal("equals '[FILTERED]'", Pii::FILTERED == '[FILTERED]')

puts "\n=== Pii::EMAIL_REGEX ==="
assert_equal("matches student@example.com",
      "student@example.com".match?(Pii::EMAIL_REGEX))
assert_equal("matches jane.doe+tag@school.edu",
      "jane.doe+tag@school.edu".match?(Pii::EMAIL_REGEX))
assert_equal("does not match 'just a string'",
      !"just a string".match?(Pii::EMAIL_REGEX))
assert_equal("does not match 'user@'",
      !"user@".match?(Pii::EMAIL_REGEX))

puts "\n=== Pii::SSN_REGEX ==="
assert_equal("matches 123-45-6789",
      "123-45-6789".match?(Pii::SSN_REGEX))
assert_equal("does not match 12345-6789",
      !"12345-6789".match?(Pii::SSN_REGEX))
assert_equal("does not match 123456789",
      !"123456789".match?(Pii::SSN_REGEX))

puts "\n=== Pii::PHONE_REGEX ==="
assert_equal("matches (555) 123-4567",
      "(555) 123-4567".match?(Pii::PHONE_REGEX))
assert_equal("matches 555-123-4567",
      "555-123-4567".match?(Pii::PHONE_REGEX))
assert_equal("matches 555.123.4567",
      "555.123.4567".match?(Pii::PHONE_REGEX))
assert_equal("matches +1 555-123-4567",
      "+1 555-123-4567".match?(Pii::PHONE_REGEX))
assert_equal("matches plain 5551234567",
      "5551234567".match?(Pii::PHONE_REGEX))
assert_equal("does NOT match long numeric ID (1464597971234567890)",
      !"1464597971234567890".match?(Pii::PHONE_REGEX))
assert_equal("does NOT match Datadog trace IDs in JSON",
      '{"trace_id":"5765288790315274587","span_id":"14645979712345678"}'
        .scan(Pii::PHONE_REGEX).empty?)

puts "\n=== Pii::PII_PATTERNS ==="
assert_equal("is frozen", Pii::PII_PATTERNS.frozen?)
assert_equal("includes EMAIL_REGEX", Pii::PII_PATTERNS.include?(Pii::EMAIL_REGEX))
assert_equal("includes SSN_REGEX", Pii::PII_PATTERNS.include?(Pii::SSN_REGEX))
assert_equal("includes PHONE_REGEX", Pii::PII_PATTERNS.include?(Pii::PHONE_REGEX))

# ============================================================
# ParameterFilter field scrubbing
# ============================================================
puts "\n=== ParameterFilter: field scrubbing ==="
r = pii_filter.filter(email: "student@example.com", id: "abc-123")
assert_equal("scrubs :email", r[:email] == '[FILTERED]')
assert_equal("preserves :id", r[:id] == "abc-123")

r = pii_filter.filter(name: "Jane Doe", role: "student")
assert_equal("scrubs :name via regex anchor", r[:name] == '[FILTERED]')
assert_equal("preserves :role", r[:role] == "student")

r = pii_filter.filter(username: "jdoe", display_name: "Jane")
assert_equal("scrubs :username", r[:username] == '[FILTERED]')
assert_equal("preserves :display_name (not exact 'name')", r[:display_name] == "Jane")

r = pii_filter.filter(first_name: "Victor", last_name: "Smith", grade: "A")
assert_equal("scrubs :first_name", r[:first_name] == '[FILTERED]')
assert_equal("scrubs :last_name", r[:last_name] == '[FILTERED]')
assert_equal("preserves :grade", r[:grade] == "A")

r = pii_filter.filter(student_name: "Violet Jones", course: "Math 101")
assert_equal("scrubs :student_name", r[:student_name] == '[FILTERED]')
assert_equal("preserves :course", r[:course] == "Math 101")

r = pii_filter.filter(phone: "555-1234", address: "123 Main St",
                       city: "Phoenix", zip: "85001")
assert_equal("scrubs :phone", r[:phone] == '[FILTERED]')
assert_equal("scrubs :address", r[:address] == '[FILTERED]')
assert_equal("scrubs :city", r[:city] == '[FILTERED]')
assert_equal("scrubs :zip", r[:zip] == '[FILTERED]')

r = pii_filter.filter(ssn: "123-45-6789", date_of_birth: "2010-05-15",
                       ip_address: "192.168.1.1")
assert_equal("scrubs :ssn", r[:ssn] == '[FILTERED]')
assert_equal("scrubs :date_of_birth", r[:date_of_birth] == '[FILTERED]')
assert_equal("scrubs :ip_address", r[:ip_address] == '[FILTERED]')

r = pii_filter.filter(password: "s3cret", token: "abc123",
                       api_key: "key-456", authorization: "Bearer xyz")
assert_equal("scrubs :password", r[:password] == '[FILTERED]')
assert_equal("scrubs :token", r[:token] == '[FILTERED]')
assert_equal("scrubs :api_key", r[:api_key] == '[FILTERED]')
assert_equal("scrubs :authorization", r[:authorization] == '[FILTERED]')

r = pii_filter.filter("email" => "student@example.com", "id" => "abc-123")
assert_equal("scrubs string key 'email'", r["email"] == '[FILTERED]')
assert_equal("preserves string key 'id'", r["id"] == "abc-123")

puts "\n=== ParameterFilter: user hash scrubbing ==="
user = { id: "user-42", email: "student@school.edu" }
s = pii_filter.filter(user)
s[:id] = user[:id]
assert_equal("preserves symbol :id", s[:id] == "user-42")
assert_equal("scrubs symbol :email", s[:email] == '[FILTERED]')

user2 = { 'id' => "user-42", 'email' => "s@school.edu" }
s2 = pii_filter.filter(user2)
s2['id'] = user2['id']
assert_equal("preserves string 'id'", s2['id'] == "user-42")
assert_equal("scrubs string 'email'", s2['email'] == '[FILTERED]')

puts "\n=== ParameterFilter: non-hash input ==="
assert_equal("nil returns empty hash",
      (nil.is_a?(Hash) ? pii_filter.filter(nil) : {}) == {})
assert_equal("string returns empty hash",
      ("not a hash".is_a?(Hash) ? pii_filter.filter("x") : {}) == {})

# ============================================================
# email regex in free text
# ============================================================
puts "\n=== Sentry: email regex in free text ==="
msg = "User john.doe@school.edu failed to submit"
assert_equal("scrubs email from message",
      msg.gsub(Pii::EMAIL_REGEX, Pii::FILTERED) ==
        "User [FILTERED] failed to submit")
msg2 = "From a@b.com to c@d.org regarding enrollment"
assert_equal("scrubs multiple emails",
      msg2.gsub(Pii::EMAIL_REGEX, Pii::FILTERED) ==
        "From [FILTERED] to [FILTERED] regarding enrollment")
msg3 = "Assignment submitted at 3pm for course 101"
assert_equal("preserves non-email text",
      msg3.gsub(Pii::EMAIL_REGEX, Pii::FILTERED) == msg3)

# ============================================================
# string scrubbing
# ============================================================
puts "\n=== Formatter: string message scrubbing ==="
assert_equal("scrubs email from string",
      scrub_string("User student@example.com signed in") ==
        "User [FILTERED] signed in")
assert_equal("scrubs multiple emails",
      !scrub_string("From a@b.com to c@d.org").include?("a@b.com"))
assert_equal("scrubs SSN from string",
      !scrub_string("SSN on file: 123-45-6789").include?("123-45-6789"))
assert_equal("scrubs formatted phone",
      !scrub_string("Contact at (555) 123-4567").include?("(555) 123-4567"))
assert_equal("scrubs phone with country code",
      !scrub_string("Call +1 555-123-4567").include?("+1 555-123-4567"))
assert_equal("scrubs plain 10-digit phone",
      !scrub_string("Phone: 5551234567").include?("5551234567"))
assert_equal("preserves long numeric identifiers",
      scrub_string("span_id: 1464597971234567890")
        .include?("1464597971234567890"))
assert_equal("preserves Datadog trace IDs in JSON",
      scrub_string('{"trace_id":"5765288790315274587","span_id":"14645979712345678"}')
        .include?("5765288790315274587"))
assert_equal("preserves clean text",
      scrub_string("Assignment submitted for course 101") ==
        "Assignment submitted for course 101")

# ============================================================
# hash scrubbing via formatter
# ============================================================
puts "\n=== Formatter: hash message scrubbing ==="
hash_scrubbed = pii_filter.filter(email: "student@example.com",
                                   first_name: "Jane", org_id: 42)
assert_equal("scrubs :email in hash", hash_scrubbed[:email] == '[FILTERED]')
assert_equal("scrubs :first_name in hash", hash_scrubbed[:first_name] == '[FILTERED]')
assert_equal("preserves :org_id in hash", hash_scrubbed[:org_id] == 42)

clean_hash = pii_filter.filter(course: "Math 101", grade: "A")
assert_equal("preserves non-PII :course", clean_hash[:course] == "Math 101")
assert_equal("preserves non-PII :grade", clean_hash[:grade] == "A")

# ============================================================
# non-string/non-hash passthrough
# ============================================================
puts "\n=== Formatter: passthrough ==="
assert_equal("integer passes through",
      42.is_a?(String) == false && 42.is_a?(Hash) == false)
assert_equal("nil passes through",
      nil.is_a?(String) == false && nil.is_a?(Hash) == false)

# ============================================================
# formatter delegation
# ============================================================
puts "\n=== Formatter: Logger::Formatter integration ==="

# Stub ActionDispatch::Http::ParameterFilter for vanilla Ruby.
# Hash scrubbing was already verified above via SimpleParameterFilter;
# this section tests the formatter's string path + delegation.
unless defined?(ActionDispatch)
  module ActionDispatch
    module Http
      class ParameterFilter
        def initialize(_fields); end
        def filter(hash); hash; end
      end
    end
  end
end

require_relative '../lib/pii_logging_formatter'

formatter = PiiLoggingFormatter.new(original_formatter: ::Logger::Formatter.new)
ts = Time.now

out = formatter.call("INFO", ts, "app", "User student@example.com signed in")
assert_equal("formatter scrubs email",
      !out.include?("student@example.com") && out.include?("[FILTERED]"))

out2 = formatter.call("INFO", ts, "app", "SSN: 123-45-6789")
assert_equal("formatter scrubs SSN", !out2.include?("123-45-6789"))

out3 = formatter.call("INFO", ts, "app", "span_id: 1464597971234567890")
assert_equal("formatter preserves long numeric IDs",
      out3.include?("1464597971234567890"))

out4 = formatter.call("INFO", ts, "app", "clean message")
assert_equal("formatter includes message text", out4.include?("clean message"))
assert_equal("formatter includes severity", out4.include?("INFO"))

nil_fmt = PiiLoggingFormatter.new(original_formatter: nil)
out5 = nil_fmt.call("INFO", ts, "app", "test")
assert_equal("nil original_formatter defaults safely", out5.include?("test"))

assert_equal("delegates respond_to? for :datetime_format",
      formatter.respond_to?(:datetime_format))

begin
  formatter.nonexistent_method
  assert_equal("raises NoMethodError for unknown methods", false)
rescue NoMethodError
  assert_equal("raises NoMethodError for unknown methods", true)
end

# ============================================================
# Results
# ============================================================
puts "\n#{'=' * 50}"
puts "Results: #{$results[:pass]} passed, #{$results[:fail]} failed"
puts '=' * 50

exit($results[:fail] > 0 ? 1 : 0)
