require_relative '../../../../rails_helper'

RSpec.describe PipelineService::Events::Responders::SIS do
  let(:message) {{}}
  let(:object) { double(:object) }

  before do
    ENV['SIS_ENROLLMENT_UPDATE_API_KEY'] = 'key'
    ENV['SIS_ENROLLMENT_UPDATE_ENDPOINT'] = 'endpoint'
    allow(PipelineService::Events::HTTPClient).to receive(:post)
  end

  let(:sis_responder) do
    PipelineService::Events::Responders::SIS.new(
      object: object,
      message: message
    )
  end

  describe '#call' do
    context 'when missing config' do
      it 'raises a config error' do
        allow(sis_responder).to receive(:missing_config?).and_return(true)

        expect {
          sis_responder.call
        }.to raise_error('Missing config: SIS_ENROLLMENT_UPDATE_API_KEY or SIS_ENROLLMENT_UPDATE_ENDPOINT is nil')
      end
    end

    it 'enqueues itself' do
      queue = double('Queue')
      expect(queue).to receive(:enqueue).with an_instance_of(PipelineService::Events::Responders::SIS)
      allow(sis_responder).to receive(:queue).and_return queue

      sis_responder.call
    end
  end

  context '#perform' do
    it 'posts' do
      expect(sis_responder).to receive(:post)

      sis_responder.perform
    end

    it 'logs' do
      logger = double(PipelineService::Logger)
      expect(logger).to receive(:call)
      expect(PipelineService::Logger).to receive(:new).and_return(logger)

      sis_responder.perform
    end

    it 'posts to the http client' do
      expect(PipelineService::Events::HTTPClient).to receive(:post)

      sis_responder.perform
    end
  end
end
