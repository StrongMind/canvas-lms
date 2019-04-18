require_relative '../../rails_helper'

RSpec.describe PipelineService::PipelineClient do
  let(:endpoint_instance) { double('endpoint_instance', call: nil)}
  let(:endpoint_class) { double('endpoint_class', new: endpoint_instance) }
  let(:logger_class) { double('logger_class', new: logger_instance) }
  let(:logger_instance) { double('logger_class', call: nil) }

  subject do
    described_class.new(
      object: Enrollment.new,
      noun: '',
      id: 1,
      endpoint: endpoint_class,
      logger: logger_class
    )
  end

  it 'posts to the endpoint' do
    expect(endpoint_instance).to receive(:call).and_return(nil)
    subject.call
  end
end
