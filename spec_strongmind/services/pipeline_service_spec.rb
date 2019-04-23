require_relative '../rails_helper'

RSpec.describe PipelineService do
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

  before do
    allow(SettingsService).to receive(:get_settings).and_return({})
  end

  let!(:enrollment) { double('Enrollment') }
  let!(:api_instance) { double('API::Publish instance') }
  let!(:api_class) { double('API::Publish') }
  let!(:republish_instance) { double('API::Republish instance') }

  describe '#publish' do
    it 'Calls the API instance' do
      # override stub in spec_helper
      expect(PipelineService).to receive(:publish).with(enrollment, api: api_class).and_call_original

      expect(api_instance).to receive(:call)
      expect(api_class).to receive(:new).with(enrollment, noun: nil).and_return(api_instance)

      PipelineService.publish(enrollment, api: api_class)
    end

    it "Can be turned off" do
      # override stub in spec_helper
      expect(PipelineService).to receive(:publish).with(enrollment, api: api_class).and_call_original

      allow(SettingsService).to receive(:get_settings).and_return({'disable_pipeline' => true})

      expect(api_class).not_to receive(:new)

      PipelineService.publish(enrollment, api: api_class)
    end
  end

  describe '#republish' do
    let(:instance) { double('instance', call: nil) }
    let(:range) { (DateTime.now...1.hour.from_now) }

    it 'calls the api instance' do
      expect(republish_instance).to receive(:call)
      expect(PipelineService::API::Republish).to receive(:new).with(model: User, range: range).and_return(republish_instance)

      PipelineService.republish(model: User, range: range)
    end
  end
end
