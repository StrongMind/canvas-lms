require_relative '../../../rails_helper'

RSpec.describe PipelineService::Events::GradeChangedEvent do
  describe '#emit' do
    let(:subscription) { double(:subscription, responder: responder, id: 1, changes: {}) }
    let(:responder) { double(:responder, call: nil) }
    let(:submission) {
      double('submission', assignment: double('assignment', course: double('course')), user: double('user'), id: 1, changes: {} ) }
    let(:object) { PipelineService::Models::Noun.new(PipelineService::Nouns::UnitGrades.new(submission)) }
    let(:changes) { {'score' => 10} }


    before do
      allow(object).to receive(:is_a?).with(PipelineService::Nouns::UnitGrades).and_return(true)
    end

    subject do
      described_class.new(
        subscription: subscription,
        resonder: responder,
        object: object,
        changes: changes
      )
    end

    context 'The grade changed' do
      it 'calls the responder' do
        expect(responder).to receive(:call)
        subject.emit
      end
    end

    context "The grade did not change" do
      let(:changes) { {} }
      it 'does not call the responder' do
        subject.emit
      end
    end
  end
end
