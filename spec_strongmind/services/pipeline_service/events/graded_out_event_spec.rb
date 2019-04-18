require_relative '../../../rails_helper'

RSpec.describe PipelineService::Events::GradedOutEvent do
  let(:subscription) { double(:subscription, responder: responder) }
  let(:responder) { double(:responder, call: nil) }
  let(:object) { PipelineService::Models::Noun.new(StudentEnrollment.new) }
  let(:changes) { {} }

  subject do
    described_class.new(
      subscription: subscription,
      object: object,
      changes: changes
    )
  end

  describe '#emit' do
    it 'calls the responder' do
      expect(responder).to receive(:call)
      subject.emit
    end
  end
end
