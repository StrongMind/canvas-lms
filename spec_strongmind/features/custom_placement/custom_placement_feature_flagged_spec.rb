
require_relative '../../rails_helper'

RSpec.describe 'As a System with custom placement behind feature flag', type: :feature, js: true do

  include_context 'stubbed_network'

  it "can be turned on with a 'enable_custom_placement' feature flag" do
    visit "/courses/#{@course.id}"

    allow_any_instance_of(TeacherEnrollment).to receive(:has_permission_to?).and_return(true)

    click_link 'People'

    within find("#user_#{@student.id}") do
      find('.al-trigger').click()
      sleep 2
      expect(page).to have_selector('a[href="#"][data-event=editEnrollments]', text: 'Custom Placement')
    end
  end
end
