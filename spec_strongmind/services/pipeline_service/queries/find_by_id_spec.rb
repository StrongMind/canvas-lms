require_relative '../../../rails_helper'

RSpec.describe PipelineService::Queries::FindByID do
    include_context 'stubbed_network'

    subject { described_class }
    let(:conversation)  { Conversation.create }
    let(:noun)          { PipelineService::Models::Noun.new(conversation) }
    let(:builder)       { PipelineService::Builders::ConversationJSONBuilder }

    it 'returns a ruby hash of the object' do
        expect(subject.query(builder, noun))
            .to eq(builder.call(noun))
    end
end