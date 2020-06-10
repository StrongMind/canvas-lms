
require_relative '../../rails_helper'

RSpec.describe 'As a System with custom placement behind feature flag', type: :feature, js: true do

  include_context 'stubbed_network'

  before(:each) do
    student_in_course(active_all: true)
    course_with_teacher_logged_in(course: @course)
  end

  it "should be off by default and can be turned on with a 'enable_custom_placement' feature flag" do
    visit "/courses/#{@course.id}"

    expect(page).to have_selector('a.home.active')

    click_link 'People'

    within find("#user_#{@student.id}") do
      find('.al-trigger').click()
      sleep 1
      expect(page).to_not have_selector('a[href="#"][data-event=editEnrollments]', text: 'Custom Placement')
    end

    # Turn on feature flag!
    allow_any_instance_of(TeacherEnrollment).to receive(:has_permission_to?).with(:custom_placement).and_return(true)
    allow_any_instance_of(TAEnrollment).to receive(:has_permission_to?).with(:custom_placement).and_return(true)

    visit "/courses/#{@course.id}"

    expect(page).to have_selector('a.home.active')

    click_link 'People'

    within find("#user_#{@student.id}") do
      find('.al-trigger').click()
      sleep 1
      expect(page).to have_selector('a[href="#"][data-event=editEnrollments]', text: 'Custom Placement')
    end
  end
end
