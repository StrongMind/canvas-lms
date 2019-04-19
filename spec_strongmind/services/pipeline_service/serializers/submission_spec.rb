require_relative '../../../rails_helper'

RSpec.describe PipelineService::Serializers::Submission, skip: 'todo: fix for running under LMS' do
  subject do
    described_class.new object: submission
  end

  let(:expected_endpoint) do
    "https://#{ENV['CANVAS_DOMAIN']}/api/v1/courses/#{course.id}/assignments/#{assignment.id}/submissions/#{user.id}"
  end

  let(:expected_api_result) do
    { "assignment_id": assignment.id,
      "assignment": "Assignment",
      "course": "Course",
      "attempt": 1,
      "body": "There are three factors too...",
      "grade": "A-",
      "grade_matches_current_submission": true,
      "score": 13.5,
      "submission_comments": nil,
      "submission_type": "online_text_entry",
      "submitted_at": "2012-01-01T01:00:00Z",
      "url": nil,
      "user_id": 134,
      "grader_id": 86,
      "graded_at": "2012-01-02T03:05:34Z",
      "user": "User",
      "late": false,
      "assignment_visible": true,
      "excused": true,
      "missing": true,
      "late_policy_status": "missing",
      "points_deducted": 12.3,
      "seconds_late": 300,
      "extra_attempts": 10,
      "workflow_state": "submitted"
    }.to_json
  end

  let(:headers) { { Authorization: "Bearer #{ENV['STRONGMIND_INTEGRATION_KEY']}" } }
  let(:course) { Course.create }
  let(:assignment) { Assignment.create(course: course) }
  let(:user) { User.create }
  let(:submission) { Submission.create(submitted_at: Time.now, assignment: assignment, user: user) }
  let(:integration_key) { rand.to_s }
  let(:canvas_domain) { Faker::Internet.domain_name }
  let(:canvas_api_client) { double("Canvas API Client") }
  let(:canvas_api_client_result) { { "user_id" => user.id } }

  before do
    allow(PipelineService).to receive(:publish)
    ENV['CANVAS_DOMAIN'] = canvas_domain
    ENV['STRONGMIND_INTEGRATION_KEY'] = integration_key
    allow(SettingsService).to receive(:get_settings).and_return('enable_unit_grade_calculations': true)
    allow(PipelineService::HTTPClient).to receive(:get).with(
        expected_endpoint,
        headers: headers
    ).and_return(expected_api_result)

    allow(Pandarus::Client).to receive(:new).and_return(canvas_api_client)
    allow(canvas_api_client).to receive(:get_single_submission_courses).with(
        course.id,
        assignment.id,
        user.id,
        {:include=>["submission_history"]}
    ).and_return(canvas_api_client_result)
  end

  it 'returns an enrollment object with a user id' do
    result = subject.call
    expect(result['user_id']).to eq(user.id)
  end
end
