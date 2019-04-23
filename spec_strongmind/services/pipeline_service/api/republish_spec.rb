require_relative '../../../rails_helper'

RSpec.describe PipelineService::API::Republish, skip: 'todo: fix for running under LMS' do
  include_context "stubbed_network"
  subject do
    described_class.new(
      model: PipelineService::Nouns::UnitGrades,
      range: range
    )
  end
  let(:range) {3.days.ago...DateTime.now}

  let(:submission) do
    double(
      "submission",
      user: double('user'),
      id: 1,
      assignment: double('assignment',
        course: double('course')
      ),
      changes: {}
    )
  end

  let(:collection) {double('collection')}


  let(:unit_grades_instance) { double('unit_grades_instance') }

  before do
    class_double('::Assignment', where: collection, column_names: ['updated_at']).as_stubbed_const
    class_double('::ConversationMessage', where: collection, column_names: ['updated_at']).as_stubbed_const
    class_double('::ConversationParticipant', where: collection, column_names: ['updated_at']).as_stubbed_const
    class_double('::Conversation', where: collection, column_names: ['updated_at']).as_stubbed_const
    class_double('::Enrollment', where: collection, column_names: ['updated_at']).as_stubbed_const
    class_double('::User', where: collection, column_names: ['updated_at']).as_stubbed_const

    class_double("Submission", where: collection, column_names: ['created_at']).as_stubbed_const
    class_double("PipelineService::Nouns::UnitGrades", new: unit_grades_instance).as_stubbed_const
    allow(collection).to receive(:find_each).and_yield(submission)
  end

  describe '#call' do
    it 'uses #created_at if #updated_at does not exist' do
      expect(Submission).to receive(:where).with(hash_including(created_at: range)).and_return(collection)
      subject.call
    end

    it 'publishes specific records' do
      expect(PipelineService).to receive(:publish).with(submission)
      subject.call
    end

    context 'when missing a range' do
      subject do
        described_class.new(model: PipelineService::Nouns::UnitGrades)
      end

      it 'requires a range' do
        expect{subject.call}.to raise_error("Missing required date range")
      end
    end

    context 'when no model specified' do
      subject do
        described_class.new(range: range)
      end

      it 'publishes all records' do
        PipelineService::Serializers.repositories.each do |model_class|
          expect(model_class).to receive(:where).and_return(collection)
        end
        subject.call
      end
    end

    context 'when publishing a submission' do
      subject do
        described_class.new(
          model: Submission,
          range: range
        )
      end

      it 'wraps submissions in a unit grade instance' do
        expect(PipelineService).to receive(:publish).with(unit_grades_instance)
        subject.call
      end
    end
  end
end