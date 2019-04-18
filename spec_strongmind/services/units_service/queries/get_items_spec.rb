require_relative '../../../rails_helper'

RSpec.describe UnitsService::Queries::GetItems do
  let(:course) { Course.create(context_modules: [context_module]) }
  let(:content_tag) { ContentTag.create(content: assignment) }
  let(:context_module) { ContextModule.create(content_tags: [content_tag]) }
  let(:assignment) { Assignment.create(workflow_state: 'published') }

  let!(:discussion_course) { Course.create(context_modules: [discussion_context_module]) }
  let!(:discussion_topic) { DiscussionTopic.create(workflow_state: 'active') }
  let!(:discussion_context_module) { ContextModule.create(content_tags: [discussion_content_tag]) }
  let!(:discussion_assignment) { Assignment.create(discussion_topic: discussion_topic, workflow_state: 'published') }
  let!(:discussion_content_tag) { ContentTag.create(content: discussion_topic) }

  let(:submission) { Submission.create(assignment: assgnment) }

  # {<context_module>: []}
  let(:empty_result) do
    {}.tap { |hash| hash[context_module] = []}
  end

  subject { described_class.new(course: course) }

  context 'tags with content' do
    let(:content_tag) { ContentTag.create(content: assignment) }

    it 'returns a content tag' do
      result = {}
      result[context_module] = [content_tag]
      expect(subject.query).to eq(result)
    end
  end

  context 'content is a discussion topic' do
    subject { described_class.new(course: discussion_course) }

    it 'returns a content tag' do
      result = {}
      result[discussion_context_module] = [discussion_content_tag]
      expect(subject.query).to eq(result)
    end
  end

  context 'tags without content' do
    let(:content_tag) { ContentTag.create(content: nil) }
    it 'does not return a content tag' do
      expect(subject.query).to eq(empty_result)
    end
  end

  context 'content without submission' do
    let(:unsubmittable_content) { Course.create }
    let(:content_tag) { ContentTag.create(content: unsubmittable_content) }
    it 'does not return a content tag' do
      expect(subject.query).to eq(empty_result)
    end
  end

  context 'where assignment is not published' do
    let(:assignment) { Assignment.create }
    it 'does not return the content tag' do
      expect(subject.query).to eq(empty_result)
    end
  end
end
