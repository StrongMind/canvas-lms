require_relative '../../../rails_helper'

RSpec.describe PipelineService::Serializers::ConversationParticipant do
  include_context "stubbed_network"

  subject { described_class.new(object: noun) }

  let(:conversation_participant_model) { ConversationParticipant.create(conversation_id: 5) }

  let(:noun) { PipelineService::Models::Noun.new(conversation_participant_model) }

  it 'Return a json hash of the noun' do
    expect(subject.call).to include( "id" => conversation_participant_model.id )
  end
end
