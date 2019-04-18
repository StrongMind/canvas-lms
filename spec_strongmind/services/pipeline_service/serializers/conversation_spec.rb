require_relative '../../../rails_helper'

RSpec.describe PipelineService::Serializers::Conversation do
  include_context "stubbed_network"
  subject { described_class.new(object: noun) }

  let(:noun) { PipelineService::Models::Noun.new(conversation_model) }
  let(:conversation_model) { Conversation.create }

  it 'returns an attribute hash for the noun' do
    expect(subject.call['id']).to eq( conversation_model.id )
  end

  it 'returns an empty hash if the conversation can not be found' do
    conversation_model.destroy
    expect(subject.call).to eq( {} )
  end
end
