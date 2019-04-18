require_relative '../../../rails_helper'

RSpec.describe PipelineService::Builders::ConversationJSONBuilder do
  subject { described_class }

  include_context('stubbed_network')

  let!(:ar_object) { c = Conversation.create; c.destroy }
  let(:noun) { PipelineService::Models::Noun.new(ar_object) }

  it "Return empty hash body if the record can't be found" do
    expect(subject.call(noun)).to eq({})
  end
end
