
require_relative '../rails_helper'

RSpec.describe 'Teacher can force advance student module progress', type: :feature, js: true do

  before(:each) do
    student_in_course(active_all: true)
    course_with_teacher_logged_in(course: @course)

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
      # tool = @course.context_external_tools.create!(:name => "b", :url => "http://www.google.com", :consumer_key => '12345', :shared_secret => 'secret')
      # external_tool_tag = @module1.add_item(:type => 'context_external_tool', :id => tool.id, :url => tool.url, :new_tab => false)

    # External Tool
      # tool = @course.context_external_tools.create!(:name => "b", :url => "http://www.google.com", :consumer_key => '12345', :shared_secret => 'secret', :tool_id => 'ewet00b')
      # @module1.add_item(:type => 'external_tool', :title => 'Tool', :id => tool.id, :url => 'http://www.google.com', :new_tab => false, :indent => 0)
      # @module1.save!

    # 'lti/message_handler'

    @module1.completion_requirements = {
      @assignment_tag.id       => { type: 'must_submit' },
      @external_url_tag.id     => { type: 'must_view' },
      @header_tag.id           => { type: 'must_view' }, # valid?
      wiki_tag.id              => { type: 'must_view' },
      @attachment_tag.id       => { type: 'must_view' },
      @topic_tag.id            => { type: 'must_contribute' },
      @group_discussion_tag.id => { type: 'must_contribute' },
      @quiz_tag.id             => { type: 'min_score', min_score: 90 },
      @assignment2_tag.id      => { type: 'must_mark_done' }
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
  end

  it "shows me some modules" do
    user_session(@student)

    visit "/courses/#{@course.id}"

    expect(page).to have_selector('a.home.active')
    sleep 5

    # USE INSTEAD?
    # content_tags_visible_to(self.user, is_teacher: false, ignore_observer_logic: true)

    @student.custom_placement_at(@m2_topic_tag) # pass a content_tag



    visit "/courses/#{@course.id}"
    sleep 5
    binding.pry
    x = 1
  end
end
