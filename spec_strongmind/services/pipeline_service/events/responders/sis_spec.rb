require_relative '../../../../rails_helper'

RSpec.describe PipelineService::Events::Responders::SIS do
  let(:message) {{}}
  let(:object) { double(:object) }

  before do
    ENV['SIS_ENROLLMENT_UPDATE_API_KEY'] = 'key'
    ENV['SIS_ENROLLMENT_UPDATE_ENDPOINT'] = 'endpoint'
    allow(PipelineService::Events::HTTPClient).to receive(:post)
  end

  subject do
    described_class.new(
      object: object,
      message: message
    )
  end
  describe '#call' do
    xit 'posts to the http client' do
      # FIXME : We believe this fails when run not alone because this is a singleton.
      expect(PipelineService::Events::HTTPClient).to receive(:post)
      subject.call
    end
  end

  context 'logging' do
    xit 'logs' do
      expect(PipelineService::Logger).to receive(:call)
      subject.call
    end
  end
end
