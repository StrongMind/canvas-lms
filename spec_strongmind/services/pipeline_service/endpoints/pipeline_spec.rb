require_relative '../../../rails_helper'

RSpec.describe PipelineService::Endpoints::Pipeline do
  around do |example|
    envs = {
      PIPELINE_ENDPOINT: 'https://example.com',
      PIPELINE_USER_NAME: 'example_user',
      PIPELINE_PASSWORD: 'example_password',
      CANVAS_DOMAIN: 'someschool.com'
    }

    ClimateControl.modify envs do
      example.run
    end
  end

  let(:message)     { {noun: 'ARRecord', id: 1} }
  let(:http_client) { double('http_client', messages_post: nil) }
  let(:serializer)  { double('serializer class', new: double('serializer instance', call: nil)) }

  let(:object) {double('object', class: Enrollment, id: 1)}

  let(:service) do
    PipelineService::Endpoints::Pipeline.new(
      object: object,
      message: message,
      args: { http_client: http_client }
    )
  end

  before do
    allow(PipelineService::HTTPClient).to receive(:post)
    allow(SettingsService).to receive(:get_settings).and_return({})
  end

  it 'uses the lowest priority' do
    expect(Delayed::Job).to receive(:enqueue).with(service, hash_including(priority: 1000000))

    service.call
  end

  it 'can be turned off' do
    allow(SettingsService).to receive(:get_settings).and_return({'disable_pipeline' => true})

    expect(Delayed::Job).to_not receive(:enqueue)

    service.call
  end
end
