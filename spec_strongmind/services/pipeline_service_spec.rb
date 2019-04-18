require_relative '../rails_helper'

RSpec.describe PipelineService do
  before do
    ENV['PIPELINE_ENDPOINT'] = 'https://example.com'
    ENV['PIPELINE_USER_NAME'] = 'example_user'
    ENV['PIPELINE_PASSWORD'] = 'example_password'
    ENV['CANVAS_DOMAIN'] = 'someschool.com'
    allow(SettingsService).to receive(:get_settings).and_return({})
  end

  subject { described_class }
  let(:serializer_instance) { double('Serializer Instance', call: nil) }
  let(:serializer) { double('Serializer', new: serializer_instance) }
  let(:enrollment) { double('Enrollment', pipeline_serializer: serializer, id: 1) }
  let(:api_instance) { double('api_instance', call: nil) }
  let(:api) { double('api', new: api_instance) }

  describe '#publish' do
    it 'Calls the API instance' do
      expect(api_instance).to receive(:call)
      subject.publish(enrollment, api: api)
    end

    it "Can be turned off" do
      allow(SettingsService).to receive(:get_settings).and_return({'disable_pipeline' => true})
      expect(api_instance).to_not receive(:call)
      subject.publish(enrollment, api: api)
    end
  end

  describe '#republish' do
    let(:instance) { double('instance', call: nil) }
    let(:range) { (DateTime.now...1.hour.from_now) }

    before do
      class_double("PipelineService::API::Republish", new: instance).as_stubbed_const
    end

    it 'calls the api instance' do
      expect(PipelineService::API::Republish).to receive(:new).with(
        model: User,
        range: range
      )
      subject.republish(model: User, range: range)
    end
  end
end

