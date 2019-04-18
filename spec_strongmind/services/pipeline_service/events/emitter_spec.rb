require_relative '../../../rails_helper'

    class UnhandledNoun
      def id
        1
      end

      def destroyed?
        false
      end

      def changes
        {}
      end
    end


RSpec.describe PipelineService::Events::Emitter do
  include_context "stubbed_network"

  let(:object) { StudentEnrollment.create }
  let(:responder_class) { double(:responder_class, new: responder) }
  let(:responder) { double(:class) }
  let(:event_class) { double('event_class') }
  let(:event) { double(:event, emit: nil) }
  let(:noun) { PipelineService::Models::Noun.new(object) }

  before do
    allow(event_class).to receive(:new).and_return(event)
    allow(subject).to receive(:events).and_return({ grade_changed: event_class })
  end

  subject do
    described_class.new(object: noun, responder: responder_class)
  end

  context 'unhandled noun' do
    let(:unhandled_noun) {double('unhandled_noun', id: 1, changes: {})}
    let(:object) { PipelineService::Models::Noun.new(unhandled_noun) }
    before do
      allow(subject).to receive(:serializer).and_return(nil)
    end

    describe '#call' do
      it 'does not emit an event' do
        expect(event).to_not receive(:emit)
        subject.call
      end
    end
  end

  context 'graded_out_event' do
    describe '#call' do
      it 'emits an event' do
        expect(event).to receive(:emit)
        subject.call
      end
    end
  end

  context 'grade_changed_event' do
    describe '#call' do
      it 'emits an event' do
        expect(event).to receive(:emit)
        subject.call
      end
    end
  end
end
