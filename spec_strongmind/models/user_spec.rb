require_relative '../rails_helper'

RSpec.describe User do
  before(:all) do
    @admin_user = site_admin_user
  end

  let!(:teacher) { teacher_in_course; @teacher }
  let!(:discussion_topic) { discussion_topic_model(context: @course) }
  let!(:assignment) do
    assignment_model(context: @course)
    @a.update discussion_topic: discussion_topic
    @a
  end
  let(:response) { double('response', body: [discussion_topic.id].to_json, code: 200) }

  before do
    ENV['TOPIC_MICROSERVICE_ENDPOINT'] = 'endpoint'
    ENV['TOPIC_MICROSERVICE_API_KEY'] = 'key'

    allow(HTTParty).to receive(:get).and_return(response)
  end

  describe '#get_teacher_unread_discussion_topic_assignments' do
    it 'is mixed in' do
      expect(teacher).to respond_to(:get_teacher_unread_discussion_topic_assignments)
    end

    it 'calls the endpoint' do
      expect(HTTParty).to receive(:get).and_return(response)
      teacher.get_teacher_unread_discussion_topic_assignments(@course)
    end

    it 'returns a list of assignments' do
      expect(teacher.get_teacher_unread_discussion_topic_assignments(@course)).to eq [assignment]
    end

    context "missing configuration" do
      before do
        ENV['TOPIC_MICROSERVICE_ENDPOINT'] = nil
        ENV['TOPIC_MICROSERVICE_API_KEY'] = nil
      end

      it 'wont look up enrollments' do
        expect(teacher).to_not receive(:enrollments) # self.enrollments.where(...).empty?
        teacher.get_teacher_unread_discussion_topic_assignments(@course)
      end

      it "wont call the service" do
        expect(HTTParty).to_not receive(:get)
        teacher.get_teacher_unread_discussion_topic_assignments(@course)
      end
    end
  end

  describe "#recent_feedback" do
    include_context "stubbed_network"

    let(:student1) { student_in_course(course: @course).user }
    let(:student2) { student_in_course(course: @course).user }
    let(:student3) { student_in_course(course: @course).user }
    let(:student4) { student_in_course(course: @course).user }

    let!(:teacher_graded_submission) do
      sub = graded_submission_model(assignment: assignment, user: student1)
      sub.update(graded_at: Time.zone.now, grader_id: teacher.id, score: '5')
      sub
    end
    # autograded submissions have the grader_id of (quiz_id x -1) note: That's multiplication
    let!(:auto_graded_submission) do
      sub = graded_submission_model(assignment: assignment, user: student2)
      sub.update(graded_at: Time.zone.now, grader_id: -6, score: '5')
      sub
    end
    let!(:ungraded_submission) do
      sub = graded_submission_model(assignment: assignment, user: student3)
      sub.update(graded_at: Time.zone.now, grader_id: nil, score: '5')
      sub
    end
    let!(:zero_grader_graded_submission) do
      sub = graded_submission_model(assignment: assignment, user: student4)
      sub.update(graded_at: Time.zone.now, grader_id: 1, score: '5')
      sub
    end

    before do
      assignment.update_submission(student1, {:comment => "Well here's the thing...", :commenter => teacher})
    end

    it "guards for nil grader_id" do
      expect do
        student3.recent_feedback(contexts: [@course])
      end.not_to raise_error
    end

    it "returns teacher-graded feedback" do
      grader_ids = student1.recent_feedback(contexts: [@course]).map(&:grader_id)
      expect(grader_ids).to include(teacher.id)
      expect(grader_ids).not_to include(@admin_user.id)

      grader_ids = student2.recent_feedback(contexts: [@course]).map(&:grader_id)
      expect(grader_ids).to be_empty

      grader_ids = student3.recent_feedback(contexts: [@course]).map(&:grader_id)
      expect(grader_ids).to be_empty

      grader_ids = student4.recent_feedback(contexts: [@course]).map(&:grader_id)
      expect(grader_ids).to be_empty
    end

    it "returns teacher-commented feedback" do
      expect(student1.recent_feedback(contexts: [@course])).to include(teacher_graded_submission)
      expect(student2.recent_feedback(contexts: [@course])).to be_empty
      expect(student3.recent_feedback(contexts: [@course])).to be_empty
      expect(student4.recent_feedback(contexts: [@course])).to be_empty
    end
  end
end