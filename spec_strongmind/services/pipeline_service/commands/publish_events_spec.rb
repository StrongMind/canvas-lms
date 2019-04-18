require_relative '../../../rails_helper'

RSpec.describe PipelineService::Commands::PublishEvents do
  describe '#call' do
    let(:emitter_class) {double('emitter_class', new: emitter_instance)}
    let(:emitter_instance) {double('emitter_instance', call: nil)}

    subject { described_class.new({}) }

    before do
      allow(PipelineService::Commands::PublishEvents).to receive(:emitter).and_return(emitter_class)
    end

    it 'calls the emitter' do
      expect(emitter_instance).to receive(:call)
      subject.call
    end
  end
end
