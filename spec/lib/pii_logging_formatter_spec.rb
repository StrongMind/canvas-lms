#
# Copyright (C) 2015 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require_relative "../spec_helper"
require "pii_logging_formatter"

describe PiiLoggingFormatter do
  let(:original_formatter) { ::Logger::Formatter.new }
  let(:formatter) { described_class.new(original_formatter: original_formatter) }
  let(:timestamp) { Time.now }
  let(:filtered) { "[FILTERED]" }

  describe "#call" do
    context "with string messages containing email addresses" do
      it "scrubs email addresses" do
        result = formatter.call("INFO", timestamp, "app",
                                "User student@example.com signed in")
        expect(result).not_to include("student@example.com")
        expect(result).to include(filtered)
      end

      it "scrubs multiple email addresses" do
        result = formatter.call("INFO", timestamp, "app",
                                "From a@b.com to c@d.org")
        expect(result).not_to include("a@b.com")
        expect(result).not_to include("c@d.org")
      end
    end

    context "with string messages containing SSNs" do
      it "scrubs SSN patterns" do
        result = formatter.call("INFO", timestamp, "app",
                                "SSN on file: 123-45-6789")
        expect(result).not_to include("123-45-6789")
        expect(result).to include(filtered)
      end
    end

    context "with string messages containing phone numbers" do
      it "scrubs formatted US phone numbers" do
        result = formatter.call("INFO", timestamp, "app",
                                "Contact at (555) 123-4567")
        expect(result).not_to include("(555) 123-4567")
        expect(result).to include(filtered)
      end

      it "scrubs phone numbers with country code" do
        result = formatter.call("INFO", timestamp, "app",
                                "Call +1 555-123-4567")
        expect(result).not_to include("+1 555-123-4567")
        expect(result).to include(filtered)
      end

      it "scrubs plain 10-digit phone numbers" do
        result = formatter.call("INFO", timestamp, "app",
                                "Phone: 5551234567")
        expect(result).not_to include("5551234567")
        expect(result).to include(filtered)
      end

      it "does not scrub long numeric identifiers" do
        result = formatter.call("INFO", timestamp, "app",
                                "span_id: 1464597971234567890")
        expect(result).to include("1464597971234567890")
        expect(result).not_to include(filtered)
      end

      it "does not scrub Datadog trace IDs in JSON" do
        json_msg = '{"trace_id":"5765288790315274587","span_id":"14645979712345678"}'
        result = formatter.call("INFO", timestamp, "app", json_msg)
        expect(result).to include("5765288790315274587")
        expect(result).to include("14645979712345678")
        expect(result).not_to include(filtered)
      end
    end

    context "with hash messages" do
      it "scrubs PII key-value pairs" do
        result = formatter.call("INFO", timestamp, "app",
                                { email: "student@example.com",
                                  first_name: "Jane", org_id: 42 })
        expect(result).not_to include("student@example.com")
        expect(result).not_to include("Jane")
        expect(result).to include("42")
      end

      it "preserves non-PII keys" do
        result = formatter.call("INFO", timestamp, "app",
                                { course: "Math 101", grade: "A" })
        expect(result).to include("Math 101")
        expect(result).to include("A")
      end
    end

    context "with non-string non-hash messages" do
      it "passes through integer messages unchanged" do
        result = formatter.call("INFO", timestamp, "app", 42)
        expect(result).to include("42")
      end

      it "passes through nil messages" do
        result = formatter.call("INFO", timestamp, "app", nil)
        expect(result).to be_a(String)
      end
    end
  end

  describe "formatter delegation" do
    it "delegates to original formatter for output" do
      result = formatter.call("INFO", timestamp, "app", "clean message")
      expect(result).to include("clean message")
      expect(result).to include("INFO")
    end

    it "defaults to Logger::Formatter when nil is provided" do
      nil_formatter = described_class.new(original_formatter: nil)
      result = nil_formatter.call("INFO", timestamp, "app", "test")
      expect(result).to include("test")
    end
  end

  describe "method delegation" do
    it "delegates unknown methods to original formatter" do
      expect(formatter.respond_to?(:datetime_format)).to be true
    end

    it "raises NoMethodError for truly unknown methods" do
      expect { formatter.nonexistent_method }.to raise_error(NoMethodError)
    end
  end
end
