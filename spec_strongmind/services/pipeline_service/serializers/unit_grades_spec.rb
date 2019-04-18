require_relative '../../../rails_helper'

RSpec.describe PipelineService::Serializers::UnitGrades do
  include_context 'stubbed_network'

  describe 'Unit grade serializer' do
    context 'when given a submission' do
      subject { described_class.new(object: unit_grades)}

      let(:assignment) { Assignment.create(course: course) }
      let(:course) { Course.create }
      let(:pseudonym) { Pseudonym.create }
      let(:student) { User.create(pseudonym: pseudonym) }
      let(:submission) { Submission.create(assignment: assignment, user: student) }
      let(:unit_grades) { PipelineService::Nouns::UnitGrades.new(submission) }
      let(:random_string) { rand.to_s }
      let(:command_instance) { double('CommandInstance', call: { foo: random_string }) }

      before do
        allow(UnitsService::Commands::GetUnitGrades).to(
          receive(:new).with(course: course, student: student, submission: submission).and_return(command_instance)
        )
      end

      context '#call' do
        it 'returns a hash' do
          expect(subject.call.class).to eq(Hash)
        end

        it 'returns results from the UnitService' do
          expect(subject.call[:foo]).to eq(random_string)
        end
      end
    end
  end
end
