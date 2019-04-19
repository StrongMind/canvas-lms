require_relative '../../../rails_helper'

RSpec.describe PipelineService::Models::Noun do
  include_context('stubbed_network')

  before do
    course_with_teacher(:active_all => true)
    student_in_course(:active_all => true, course: @course)
    @student1                     = @student
    student_in_course(:active_all => true, course: @course)
    @student2                     = @student

    @assignment                   = @course.assignments.create!(title: "some assignment 1")

    @submission                   = @assignment.submit_homework(@student1)

    @submission_noun              = PipelineService::Models::Noun.new(@submission)

    conversation_participant      = @teacher.initiate_conversation([@student1])
    @conversation                 = conversation_participant.conversation

    @deleted_conversation         = @teacher.initiate_conversation([@student2]).conversation
    @deleted_conversation.destroy

    teacher_enrollment            = @teacher.enrollments.first
    @teacher_enrollment_noun       = PipelineService::Models::Noun.new(teacher_enrollment)
    @conversation_noun            = PipelineService::Models::Noun.new(@conversation)
    @deleted_conversation_noun    = PipelineService::Models::Noun.new(@deleted_conversation)

    @unit_grades                  = PipelineService::Nouns::UnitGrades.new(@submission)
    @unit_grades_noun             = PipelineService::Models::Noun.new(@unit_grades)
    @changes                      = {'workflow_state' => ['active', 'completed']}

    @conversation_participant_noun = PipelineService::Models::Noun.new(conversation_participant)
  end

  before do
    # allow(@conversation).to receive(:try).with(:workflow_state).and_return(nil)
    allow(@conversation).to receive(:try).with(:destroyed?).and_return(false)

    # allow(@deleted_conversation).to receive('workflow_state').and_return 'deleted'
    # allow(@deleted_conversation).to receive('state').and_return 'deleted'

    allow(@conversation).to receive(:changes).and_return(@changes)

    class_double("PipelineService::Serializers::Enrollment").as_stubbed_const
  end

  describe '#name' do
    it 'uses the passed in class name as the name' do
      expect(@unit_grades_noun.name).to eq 'unit_grades'
    end
  end

  describe '#id' do
    it 'uses the passed in object id' do
      expect(@conversation_noun.id).to eq @conversation.id
    end
  end

  describe '#changes' do
    it 'uses the passed in object changes' do
      skip 'conversations dont have workflow state'
      expect(@conversation_noun.changes).to eq @changes
    end
  end

  describe '#destroyed?' do
    it 'true if state is "deleted"' do
      expect(@deleted_conversation_noun.destroyed?).to eq true
    end
  end

  describe '#status' do
    it 'can be nil' do
      expect(@conversation_noun.status).to be_nil
    end

    it 'matches the workflow state' do
      # TODO: fix me with an object that actually has workflow_state
      skip 'conversations dont have workflow state'
      allow(@conversation).to receive(:try).with(:workflow_state).and_return('active')
      expect(@conversation_noun.status).to eq 'active'
    end

    it 'can be deleted' do
      expect(@deleted_conversation_noun.status).to eq 'deleted'
    end
  end

  describe '#noun_class' do
    it 'returns an active record class so we can query' do
      expect(@conversation_noun.noun_class).to eq Conversation
    end
  end

  describe '#fetch' do
    it 'returns a new instance fetched from the database' do
      @submission.update_column(:workflow_state, 'newstate')
      new_noun = @submission_noun.fetch
      expect(new_noun.status).to eq 'newstate'
    end
  end

  describe '#valid?' do
    it 'is valid if all of the additional ids are present' do
      expect(@submission_noun).to be_valid
    end

    it 'is not valid if any of the additional ids are missing' do
      expect(PipelineService::Models::Noun.new(Submission.new(assignment: Assignment.new(course: Course.new)))).to_not be_valid
    end
  end

  describe '#serializer' do
    it 'Conversations' do
      expect(@conversation_noun.serializer).to eq PipelineService::Serializers::Conversation
    end

    it 'TeacherEnrollments' do
      expect(@teacher_enrollment_noun.serializer).to eq PipelineService::Serializers::Enrollment
    end
  end

  describe '#additional_identifiers' do
    it 'contains required linking ids' do
      expect(
        @conversation_participant_noun.additional_identifiers
      ).to eq( conversation_id: @conversation.id )
    end

    it 'works with a submission' do
      noun = PipelineService::Models::Noun.new(@submission)

      expect(noun.additional_identifiers).to eq(
        :assignment_id => @assignment.id,
        :course_id => @course.id
      )
    end
  end
end
