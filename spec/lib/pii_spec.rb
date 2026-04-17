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
require "pii"

describe Pii do
  describe "DEFAULT_FIELDS" do
    it "is frozen" do
      expect(Pii::DEFAULT_FIELDS).to be_frozen
    end

    it "includes core PII field symbols" do
      %i[email first_name last_name student_name username phone
         phone_number address ssn date_of_birth password].each do |field|
        expect(Pii::DEFAULT_FIELDS).to include(field)
      end
    end

    it "includes regex anchors for name and ip" do
      regexes = Pii::DEFAULT_FIELDS.select { |f| f.is_a?(Regexp) }
      expect(regexes).to include(/\Aname\z/i)
      expect(regexes).to include(/\Aip\z/i)
    end
  end

  describe "FILTERED" do
    it "equals [FILTERED]" do
      expect(Pii::FILTERED).to eq("[FILTERED]")
    end
  end

  describe "EMAIL_REGEX" do
    it "matches standard email addresses" do
      expect("student@example.com").to match(Pii::EMAIL_REGEX)
      expect("jane.doe+tag@school.edu").to match(Pii::EMAIL_REGEX)
    end

    it "does not match non-email text" do
      expect("just a string").not_to match(Pii::EMAIL_REGEX)
      expect("user@").not_to match(Pii::EMAIL_REGEX)
    end
  end

  describe "SSN_REGEX" do
    it "matches SSN patterns" do
      expect("123-45-6789").to match(Pii::SSN_REGEX)
    end

    it "does not match non-SSN numbers" do
      expect("12345-6789").not_to match(Pii::SSN_REGEX)
      expect("123456789").not_to match(Pii::SSN_REGEX)
    end
  end

  describe "PHONE_REGEX" do
    it "matches US phone numbers" do
      expect("(555) 123-4567").to match(Pii::PHONE_REGEX)
      expect("555-123-4567").to match(Pii::PHONE_REGEX)
      expect("555.123.4567").to match(Pii::PHONE_REGEX)
      expect("+1 555-123-4567").to match(Pii::PHONE_REGEX)
    end

    it "matches plain 10-digit phone numbers" do
      expect("5551234567").to match(Pii::PHONE_REGEX)
    end

    it "does not match long numeric identifiers" do
      expect("1464597971234567890").not_to match(Pii::PHONE_REGEX)
    end

    it "does not match Datadog trace IDs in JSON" do
      json = '{"trace_id":"5765288790315274587","span_id":"14645979712345678"}'
      matches = json.scan(Pii::PHONE_REGEX)
      expect(matches).to be_empty
    end
  end

  describe "PII_PATTERNS" do
    it "is frozen" do
      expect(Pii::PII_PATTERNS).to be_frozen
    end

    it "includes all three regex patterns" do
      expect(Pii::PII_PATTERNS).to include(Pii::EMAIL_REGEX)
      expect(Pii::PII_PATTERNS).to include(Pii::SSN_REGEX)
      expect(Pii::PII_PATTERNS).to include(Pii::PHONE_REGEX)
    end
  end
end
