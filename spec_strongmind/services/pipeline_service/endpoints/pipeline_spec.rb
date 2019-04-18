require_relative '../../../rails_helper'

RSpec.describe PipelineService::Endpoints::Pipeline do
  let(:message) { { noun: 'ARRecord', id: 1 } }
  let(:http_client) { double('http_client', messages_post: nil) }
  let(:serializer) {double('serializer class', new: double('serializer instance', call: nil))}

  let(:object) {double('object', class: Enrollment, id: 1)}

  subject{ described_class.new(object: object, message: message, args: { http_client: http_client }) }

  before do
    ENV['PIPELINE_ENDPOINT'] = 'https://example.com'
    ENV['PIPELINE_USER_NAME'] = 'example_user'
    ENV['PIPELINE_PASSWORD'] = 'example_password'
    ENV['CANVAS_DOMAIN'] = 'someschool.com'
    allow(PipelineService::HTTPClient).to receive(:post)
    allow(SettingsService).to receive(:get_settings).and_return({})
  end

  xit 'uses the lowest priority' do
    expect(Delayed::Job).to receive(:enqueue).with(subject, hash_including(priority: 1000000))
    subject.call
  end

  it 'can be turned off' do
    allow(SettingsService).to receive(:get_settings).and_return({'disable_pipeline' => true})
    expect(Delayed::Job).to_not receive(:enqueue)
    subject.call
  end
end
