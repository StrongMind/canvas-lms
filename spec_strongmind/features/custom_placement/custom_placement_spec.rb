
require_relative '../../rails_helper'

RSpec.describe 'As a Teacher I can force advance student module progress', type: :feature, js: true do

  include_context 'stubbed_network'

  before(:each) do
    course_with_teacher_logged_in()

  # Module 1 -------

    @module1 = @course.context_modules.create!(:name => "Module 1")

  # Assignment
    @assignment = @course.assignments.create!(:name => "Assignment: pls submit", :submission_types => ["online_text_entry"], :points_possible => 42)
    @assignment.publish
    @assignment_tag = @module1.add_item(:id => @assignment.id, :type => 'assignment', :title => 'Assignment: requires submission')

  # External Url
    @external_url_tag = @module1.add_item(type: 'external_url', url: 'http://example.com/lolcats', title: 'External Url: requires viewing')
    @external_url_tag.publish

  # Context Module Sub Header
    @header_tag = @module1.add_item(:type => "sub_header", :title => "Context Module Sub Header")

  # Assignment: must_mark_done
    @assignment2 = @course.assignments.create!(:name => "Assignment: Must Mark Done", :submission_types => ["online_text_entry"])
    @assignment2.publish
    @assignment2_tag = @module1.add_item(:id => @assignment2.id, :type => 'assignment', :title => 'Assignment: requires mark done')

  # Wiki Page or Page
    wiki     = @course.wiki_pages.create! :title => "Wiki Page"
    wiki_tag = @module1.add_item(:id => wiki.id, :type => 'wiki_page', :title => 'Wiki Page: requires viewing')

  # Attachment or File
    @attachment     = attachment_model(:context => @course, display_name: 'Attachment')
    @attachment_tag = @module1.add_item(:id => @attachment.id, :type => 'attachment', :title => 'Attachment: requires viewing')

  # Discussion Topic
    @topic     = @course.discussion_topics.create!
    @topic_tag = @module1.add_item({:id => @topic.id, :type => 'discussion_topic', :title => 'Discussion Topic: requires contribution'})

  # Group Discussion
    @group_discussion = group_assignment_discussion(course: @course)

    @group_discussion_tag = @module1.add_item(type: 'discussion_topic', id: @root_topic.id, title: 'Group Discussion: requires contribution')
    @group.add_user @student, 'accepted'


  # Quiz
    # quiz_type can be assignment or survey
    @quiz = @course.quizzes.build(:title => "Some Quiz", :quiz_type => "assignment",
                                  :scoring_policy => 'keep_highest')
    @quiz.workflow_state = 'available'
    @quiz.save!

    @quiz_tag = @module1.add_item({:id => @quiz.id, :type => 'quiz', :title => 'Quiz: min score 90'})

  # Context External Tool
    tool = @course.context_external_tools.create!(:name => "Context External Tool", :url => "http://www.google.com", :consumer_key => '12345', :shared_secret => 'secret')
    @external_tool_tag = @module1.add_item(:id => tool.id, :type => 'context_external_tool', :url => tool.url, :new_tab => false, :indent => 0)
    @external_tool_tag.publish!

    # External Tool
      # tool = @course.context_external_tools.create!(:name => "b", :url => "http://www.google.com", :consumer_key => '12345', :shared_secret => 'secret', :tool_id => 'ewet00b')
      # @module1.add_item(:type => 'external_tool', :title => 'Tool', :id => tool.id, :url => 'http://www.google.com', :new_tab => false, :indent => 0)
      # @module1.save!

    # 'lti/message_handler'

    @module1.completion_requirements = {
      @assignment_tag.id        => { type: 'must_submit' },
      @external_url_tag.id      => { type: 'must_view' },
      @header_tag.id            => { type: 'must_view' }, # valid?
      wiki_tag.id               => { type: 'must_view' },
      @attachment_tag.id        => { type: 'must_view' },
      @topic_tag.id             => { type: 'must_contribute' },
      @group_discussion_tag.id  => { type: 'must_contribute' },
      @quiz_tag.id              => { type: 'min_score', min_score: 90 },
      @external_tool_tag.id     => { type: 'must_view' },
      @assignment2_tag.id       => { type: 'must_mark_done' }
    }

    @module1.save!

  # Module 2 -------

    @module2 = @course.context_modules.create!(:name => "Module 2", :require_sequential_progress => true)

    @module2.prerequisites = "module_#{@module1.id}"

  # Module 2 Assignment
    @m2_assignment = @course.assignments.create!(:name => "Module 2 Assignment: pls submit", :submission_types => ["online_text_entry"], :points_possible => 42)
    @m2_assignment.publish
    @m2_assignment_tag = @module2.add_item(:id => @m2_assignment.id, :type => 'assignment', :title => 'Module 2 Assignment: requires submission')

  # Discussion Topic
    @m2_topic     = @course.discussion_topics.create!
    @m2_topic_tag = @module2.add_item({:id => @m2_topic.id, :type => 'discussion_topic', :title => 'Module 2 Discussion Topic: requires contribution'})


    @module2.completion_requirements = {
      @m2_assignment_tag.id => { type: 'must_submit' },
      @m2_topic_tag.id      => { type: 'must_contribute' }
    }

    @module2.save!

    student_in_course(course: @course, active_all: true)

    @module1.find_or_create_progressions(@student)
    @module2.find_or_create_progressions(@student)

    # Lock progressions
    @module2.reload.relock_progressions

    # We want to also ensure Progressions get unlocked during custom placement.
    # Attempting to mirror issue seen on dev where module requirements are passed but they're
    # still in a locked state
    progressions = @student.context_module_progressions.order('context_module_id ASC')
    expect(progressions.all?(&:locked?)).to be true

    Delayed::Testing.drain
  end

  it "by selecting a unit in a upcoming module, bypasses all the requirements of the units & modules.  And modules are unlocked correctly" do
    visit "/courses/#{@course.id}"

    expect(page).to have_selector('a.home.active')

    click_link 'People'

    within find("#user_#{@student.id}") do
      find('.al-trigger').click()
      sleep 1
      click_link 'Edit Enrollment'
    end

    expect(page).to have_selector('.ui-dialog', visible: true)

    select "Module 2 Discussion Topic: requires contribution", from: 'Unit to start'

    within '.ui-dialog' do
      click_button 'Update'
    end

    accept_confirm

    sleep 2

    expect(page).to have_selector('.ic-flash-success', text: 'Custom placement process started. You can check progress by viewing the course as the student.')

    # switch to student check course progress indicators
    destroy_session
    user_session(@student)

    Capybara.ignore_hidden_elements = false

    Delayed::Testing.drain # run all queued jobs

    visit "/courses/#{@course.id}"

    expect(page).to have_selector('a.home.active')
    expect(page).to have_selector('.icon-check', visible: false)

    within "#context_module_#{@module1.id} .ig-header" do
      expect(page).to have_content('Progress: 100%')
    end

    within("#context_module_content_#{@module1.id}") do
      expect(page).to have_selector('.icon-check[title=Completed]', count: 9, visible: false)
      expect(page).not_to have_selector('.unstarted-icon', visible: false)
    end

    within "#context_module_#{@module2.id} .ig-header" do
      expect(page).to have_content('Progress: 50%')
    end

    within("#context_module_content_#{@module2.id}") do
      expect(page).to have_selector('.icon-check[title=Completed]', count: 1)
      expect(page).to have_selector('.unstarted-icon[title="This assignment has not been started"]', count: 1)
    end

    Capybara.ignore_hidden_elements = true

    # Progressions should not be locked at this point
    progressions = @student.context_module_progressions.order('context_module_id ASC')

    expect(progressions.count).to eq(2)

    p1 = @module1.reload.evaluate_for(@student)
    expect(p1).not_to be_locked

    p2 = @module2.reload.evaluate_for(@student)
    expect(p2).not_to be_locked
  end
end
