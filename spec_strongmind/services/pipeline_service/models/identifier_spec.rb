require_relative '../../../rails_helper'

RSpec.describe PipelineService::Models::Identifier do
  let(:course) {double("Course", id: 5)}
  let(:assignment) { double('Assignment', context_id: 6, course: course) }
  let(:user) { double('User') }
  let(:conversation) { double('Conversation', id: 1) }
  let(:conversation_participant) { double('ConversationParticipant', conversation_id: 5, id: 1) }

  describe '#to_a' do
    it 'allows us to specify a field' do
      expect(described_class.new(:conversation_id).to_a(conversation_participant)).to eq([:conversation_id, 5])
    end

    it 'allows us to alias the field' do
      subject = described_class.new(:context_id, alias: :course_id)
      expect(subject.to_a(assignment)).to eq([:course_id, 6])
    end
  end

  describe '#to_h' do
    let(:submission) { double("Submission", assignment: assignment) }
    let(:assingment) { double('Assignment', course: course)}

    it do
      subject = described_class.new(:context_id, alias: :course_id)

      expect(subject.to_h).to eq(context_id: :course_id)
    end

    context "field is a proc" do
      let(:custom_proc) { Proc.new {|submission| [:course_id, submission.assignment.course.id]} }

      subject { described_class.new(custom_proc) }

      it 'calls the proc' do
        expect(subject.to_a(submission)).to eq [:course_id, course.id]
      end
    end
  end
end