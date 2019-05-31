
require_relative '../../rails_helper'

RSpec.describe 'As a Teacher I can NOT force advance a PENDING student', type: :feature, js: true do

  include_context 'stubbed_network'

  before(:each) do
    course_with_teacher_logged_in
    @student = user_with_pseudonym
    @course.enroll_user(@student, 'StudentEnrollment') #invited

    @student = @student.reload

    expect(@student.enrollments.first.workflow_state).to eq('invited')
  end

  it "pending students do not get the Edit Enrollment link in their manage dropdown options" do
    visit "/courses/#{@course.id}"

    expect(page).to have_selector('a.home.active')

    click_link 'People'

    within find("#user_#{@student.id}") do
      find('.al-trigger').click()
      sleep 1
      expect(page).not_to have_link('Initial Placement')
    end
  end
end
