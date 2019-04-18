require_relative '../../../rails_helper'

RSpec.describe PipelineService::Serializers::ConversationMessage do
  include_context "stubbed_network"

  subject { described_class.new(object: noun) }

  let(:active_record_object) { ConversationMessage.create!(conversation: Conversation.create!) }
  let(:noun) { PipelineService::Models::Noun.new(active_record_object)}

  it 'Return an attribute hash of the noun' do
    expect(subject.call).to include( { 'id' => active_record_object.id } )
  end
end
