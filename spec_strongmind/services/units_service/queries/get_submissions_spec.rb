require_relative '../../../rails_helper'

RSpec.describe UnitsService::Queries::GetSubmissions, skip: 'todo: fix for running under LMS' do
  include_context "stubbed_network"
  let(:student) { User.create }
  let(:course)  { Course.create(context_modules: [unit]) }
  let(:submission) { Submission.create!(user: student, assignment: assignment) }
  let(:assignment) { Assignment.create(course: course, published: true) }
  let(:unit) { ContextModule.create }
  let(:item) { ContentTag.create(content: assignment) }

  let(:units_result) do
    units = {}
    units[unit] = [item]
    units
  end

  subject { described_class.new(student: student, course: course) }

  before do
    allow(subject).to receive(:units).and_return(units_result)
  end

  context 'when item is a discussion topic' do
    let!(:discussion_course) { Course.create(context_modules: [discussion_context_module]) }
    let!(:discussion_topic) { DiscussionTopic.create(workflow_state: 'active') }
    let!(:discussion_context_module) { ContextModule.create(content_tags: [discussion_content_tag]) }
    let!(:discussion_assignment) { Assignment.create(discussion_topic: discussion_topic, workflow_state: 'published') }
    let!(:discussion_submission) { Submission.create!(user: student, assignment: discussion_assignment) }
    let!(:discussion_content_tag) { ContentTag.create(content: discussion_topic) }

    let(:discussion_units_result) do
      units = {}
      units[discussion_context_module] = [discussion_content_tag]
      units
    end

    before do
      allow(subject).to receive(:units).and_return(discussion_units_result)
    end

    subject { described_class.new(student: student, course: discussion_course) }

    it 'returns the submission from the related assignment' do
      result = {}
      result[discussion_context_module] = [discussion_submission]
      expect(subject.query).to eq result
    end
  end

  it 'returns the unit and its submissions' do
    result = {}
    result[unit] = [submission]
    expect(subject.query).to eq result
  end

  context "with excused submission" do
    let(:submission) do
      Submission.create!(user: student, assignment: assignment)
    end

    let(:excused_submission) do
      Submission.create!(user: student, assignment: assignment, excused: true)
    end

    it 'will not return the excused submission' do
      result = {}
      result[unit] = [submission]

      expect(subject.query[unit]).to_not include(excused_submission)
    end
  end
end
