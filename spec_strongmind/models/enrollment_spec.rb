require_relative '../rails_helper'

RSpec.describe Enrollment do
  include_context "stubbed_network"

  let(:command) { double("Command", perform: nil)}

  describe '#after_create' do
    describe 'AssignmentsService.distribute_due_dates' do
      it 'calls SetEnrollmentAssignmentDueDates command and enqueues it to run in background' do
        expect(AssignmentsService::Commands::SetEnrollmentAssignmentDueDates).to receive(:new).and_return(command)
        expect(Delayed::Job).to receive(:enqueue).with(command)
        course_with_student
      end
    end
  end
end
