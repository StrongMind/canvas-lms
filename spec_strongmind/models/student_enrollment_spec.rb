require_relative '../rails_helper'

RSpec.describe StudentEnrollment do
  before do
    ENV['PIPELINE_ENDPOINT']               = 'blah'
    ENV['PIPELINE_USER_NAME']              = 'blah'
    ENV['PIPELINE_PASSWORD']               = 'blah'
    ENV['SIS_ENROLLMENT_UPDATE_API_KEY']   = 'blah'
    ENV['SIS_ENROLLMENT_UPDATE_ENDPOINT']  = 'blah'
    ENV['SIS_UNIT_GRADE_ENDPOINT_API_KEY'] = 'blah'
    ENV['SIS_UNIT_GRADE_ENDPOINT']         = 'blah'
  end

  it 'publishes pipeline events' do
    expect(PipelineService).to receive(:publish).with(an_instance_of(StudentEnrollment))
    course_with_student
  end
end
