require_relative '../../rails_helper'

RSpec.describe PipelineService::Logger do
  describe '#call' do
    let(:message) { { foo: 'bar' } }

    subject do
      described_class.new(message: message)
    end

    xit 'enqueues the post to the logger service' do
      expect(HTTParty).to receive(:post)
      subject.call
    end
  end
end
