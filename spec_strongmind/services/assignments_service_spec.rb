require_relative '../rails_helper'

RSpec.describe AssignmentsService do
  describe '#distribute_due_dates' do
    let(:instance_with_course) { double(:command_instance, call: nil) }
    let(:instance_with_enrollment) { double(:command_instance, perform: nil) }
    let(:course)   { double(:course) }
    let(:enrollment)   { double(:enrollment) }
    let(:command_with_course)  { AssignmentsService::Commands::DistributeDueDates }
    let(:command_with_enrollment)  { AssignmentsService::Commands::SetEnrollmentAssignmentDueDates }

    before do
      allow(command_with_course).to receive(:new).with(course: course).and_return(instance_with_course)
      allow(command_with_enrollment).to receive(:new).with(enrollment: enrollment).and_return(instance_with_enrollment)

    end

    it 'can receive a course' do
      expect(instance_with_course).to receive(:call)
      described_class.distribute_due_dates(course: course)
    end

    it 'can receive an enrollment' do
      expect(instance_with_enrollment).to receive(:perform)
      described_class.distribute_due_dates(enrollment: enrollment)
    end
  end
end
