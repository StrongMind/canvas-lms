# Users
teacher_in_course; @teacher
student_in_course(course: @course).user
user_with_pseudonym(active_all: true)
user_with_pseudonym(account: Account.site_admin)
user_with_pseudonym(account: Account.default)
account_admin_user(user: @user)
site_admin_user(user: @user)
student_in_course(:active_all => 1)


# Admins/Accounts
@viewing_user   = site_admin_user(user: user_with_pseudonym(account: Account.site_admin))
@account        = Account.default
@custom_role    = custom_account_role('CustomAdmin', :account => @account)
@custom_sa_role = custom_account_role('CustomAdmin', :account => Account.site_admin)


# Course / Enrollment / Modules / Content Tags / Module Progressions
course_with_teacher_logged_in
course_with_teacher(:active_all => true)

@course.enroll_user(student_2, "StudentEnrollment", :enrollment_state => 'active')

@module = @course.context_modules.create!(:name => "some module")

@assignment                     = @course.assignments.create!(:title => "some assignment")
@tag                            = @module.add_item({:id => @assignment.id, :type => 'assignment'})
@module.completion_requirements = {@tag.id => {:type => 'must_view'}}
@module.publish
@module.save!

@mp = @user.context_module_progressions.create!(:context_module => @module)
@mp.workflow_state = 'locked'
@mp.save!


# Assignments
assignment_model

@course.assignments.create!({
        title: "value for title",
        description: "value for description",
        due_at: Time.now,
        points_possible: "1.5",
        submission_types: 'external_tool',
        external_tool_tag_attributes: {url: tool.url}
    })


# Assignment Submissions
let!(:submission) { assignment.submit_homework(student) }

submission_model

let(:submission_hash) {{
  body: 'some body text',
  submission_type: 'online_text_entry',
  grade: 0.5
}}

submission.with_versioning(:explicit => true) {
  submission.update_attributes!(:graded_at => Time.zone.now, :grader_id => teacher.id, :score => 100) }

# grader_id can be nil, teacher id, negative number or account_admin
# see spec_strongmind/models/user_spec.rb
let!(:teacher_graded_submission) do
  sub = graded_submission_model(assignment: assignment, user: student1)
  sub.update!(graded_at: Time.zone.now, grader_id: teacher.id, score: '5')
  sub
end

# comment on submission
assignment.update_submission(student1, {:comment => "Well here's the thing...", :commenter => teacher})

student3.recent_feedback(contexts: [@course])


# Conversations
@convo_participant = @teacher.initiate_conversation([@student])
user               = User.find(@convo_participant.user_id)
@account           = Account.find(user.account.id)
@convo_participant.add_message("message", { root_account_id: @account.id }) # see Conversation#add_message
@convo_participant.conversation.conversation_messages.last.destroy


# Discussions / Discussion Topics
let!(:discussion_topic) { discussion_topic_model(context: @course) }
let!(:assignment) do
  assignment_model(context: @course)
  @a.update discussion_topic: discussion_topic
  @a
end

teacher.get_teacher_unread_discussion_topic_assignments(@course)

@discussion_topic = DiscussionTopic.find_by_assignment_id(@assignment.id)

entry = @discussion_topic.discussion_entries.
    create!(:user => student, :message => @first_message)
entry.update_topic
entry.context_module_action

@attachment_thing = attachment_model(:context => student_2, :filename => 'horse.doc', :content_type => 'application/msword')

# Page Views
@request_id = SecureRandom.uuid

@page_view = PageView.new
@page_view.user       = @student
@page_view.request_id = @request_id
@page_view.remote_ip  = '10.10.10.10'
@page_view.created_at = hrs.hour.ago
@page_view.updated_at = hrs.hour.ago
@page_view.context    = @course
@page_view.save!


