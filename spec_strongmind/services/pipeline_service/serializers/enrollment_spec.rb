require_relative '../../../rails_helper'

RSpec.describe PipelineService::Serializers::Enrollment do
    describe '#additional_identifier_fields' do
         it 'has a course_id and an user_id' do
            expect(described_class.additional_identifier_fields.map(&:to_h)).to eq [{:course_id=>nil}, {:user_id=>nil}]
         end
    end
end