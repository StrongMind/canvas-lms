require_relative '../../../rails_helper'

RSpec.describe UnitsService::Commands::GetUnitGrades do
  include_context "stubbed_network"

  let(:course) { Course.create }
  let(:user) { User.create(pseudonym: Pseudonym.create) }

  before do
    allow(SettingsService).to receive(:get_settings).and_return('auto_due_dates' => nil, 'auto_enrollment_due_dates' => nil)
    @enrollment = Enrollment.create(course: course, user: user)
    allow(UnitsService::Queries::GetEnrollment).to receive(:query).and_return(@enrollment)
    allow(PipelineService).to receive(:publish)
    allow(SettingsService).to receive(:get_settings).and_return(
      'enable_unit_grade_calculations' => true
    )

    allow(Enrollment).to receive(:computed_current_score).and_return(90)
    seed
  end

  it 'calculates a weighted score for each unit' do
    result = described_class.new(course: course, student: user, submission: Submission.first).call

    expect(result[:units].count).to eq 6
    result[:units].each do |unit|
      expect(unit[:score]).to eq 75
    end
  end

  def seed
    6.times do |count|
      assignment_group1 = AssignmentGroup.create(name: "assignments", group_weight: 0.5)
      assignment_group2 = AssignmentGroup.create(name: "workbook", group_weight: 0.5)
      assignment1 = Assignment.create(workflow_state: 'published', assignment_group: assignment_group1)
      content_tag1 = ContentTag.create(content: assignment1)
      assignment2 = Assignment.create(workflow_state: 'published', assignment_group: assignment_group2)
      content_tag2 = ContentTag.create(content: assignment2)

      course.context_modules << ContextModule.create(
        content_tags: [content_tag1, content_tag2]
      )
      course.assignment_groups = [assignment_group1, assignment_group2]

      course.assignments << assignment1
      course.assignments << assignment2
      assignment1.submissions << Submission.create(user: user, assignment: assignment1, score: 50, graded_at: Time.now)
      assignment2.submissions << Submission.create(user: user, assignment: assignment2, score: 100, graded_at: Time.now)
    end
  end
end
