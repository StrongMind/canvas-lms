require_relative '../../../rails_helper'

RSpec.describe UnitsService::Commands::GetUnitGrades do
  include_context "stubbed_network"
  let(:course) { Course.create(assignment_groups: []) }
  let(:pseudonym) { Pseudonym.create(sis_user_id: 1001) }
  let(:user) { User.create(pseudonym: pseudonym) }
  let(:query_instance) { double('query instance', query: nil) }
  let(:current_time) { Time.now }
  let(:unit) { double('unit', id: 1, created_at: current_time, position: 3 ) }
  let(:calculator_instance) { double('calculator_instance', call: { unit => 54 }) }
  let(:submitted_at) { Time.now }
  let(:submission) { double('submission', submitted_at: submitted_at, graded_at: current_time, grader_id: 2) }
  let(:cm) {ContextModule.create()}
  let(:unit_submissions) { Hash.new }

  subject { described_class.new(course: course, student: user, submission: submission) }

  before do
    allow(SettingsService).to receive(:get_settings).and_return('auto_due_dates' => nil, 'auto_enrollment_due_dates' => nil)
    @enrollment = Enrollment.create(user: user, course: course)
    ENV['CANVAS_DOMAIN'] = 'canvasdomain.com'
    allow(UnitsService::Queries::GetSubmissions).to receive(:new).and_return(query_instance)
    allow(UnitsService::GradesCalculator).to receive(:new).and_return(calculator_instance)
    allow(UnitsService::Queries::GetEnrollment).to receive(:query).and_return(@enrollment)
    allow(@enrollment).to receive(:computed_current_score).and_return(90)
    allow(subject).to receive(:unit_submissions).and_return(unit_submissions)
  end


  it 'returns the calculator results' do
    unit_submissions[unit] = [submission]
    expect(subject.call).to eq(
      course_id: course.id,
      course_score: 90,
      school_domain: "canvasdomain.com",
      student_id: user.id,
      sis_user_id: 1001,
      submitted_at: submitted_at,
      units: [{
        score: 54,
        id: unit.id,
        position: unit.position
      }]
    )
  end

  describe "#submissions_graded?" do
    it "does the thing" do
      unit_submissions[cm] = [Submission.create(graded_at: current_time, grader_id: 2)]
      expect(subject.send(:submissions_graded?, cm, 54)).to eq 54
    end

    context "student has no graded submissions" do
      it 'does not do the thing' do
        unit_submissions[cm] = [Submission.create]
        expect(subject.send(:submissions_graded?, cm, 0)).to eq nil
      end
    end

    context "student has graded submissions from zerograder" do
      it 'does not do the thing' do
        unit_submissions[cm] = [Submission.create(score: 0, graded_at: current_time, grader_id: 1)]
        expect(subject.send(:submissions_graded?, cm, 0)).to eq nil
      end
    end
  end
end
