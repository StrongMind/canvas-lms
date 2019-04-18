require_relative '../rails_helper'

RSpec.describe Submission do
  context 'callbacks' do
    before do
      allow(PipelineService).to receive(:publish)
    end

    describe '#send_submission_to_pipeline' do
      before do
        allow(SettingsService).to receive(:get_settings).and_return('enable_unit_grade_calculations' => false)
      end

      it 'publishes on create' do
        expect(PipelineService).to receive(:publish).with an_instance_of(Submission)
        submission_model
      end

      it 'publishes on save' do
        @submission = submission_model
        expect(PipelineService).to receive(:publish).with an_instance_of(Submission)
        @submission.save
      end
    end

    describe '#send_unit_grades_to_pipeline' do
      before do
        ENV['PIPELINE_ENDPOINT']               = 'endpoint'
        ENV['PIPELINE_USER_NAME']              = 'name'
        ENV['PIPELINE_PASSWORD']               = 'password'
        ENV['SIS_ENROLLMENT_UPDATE_API_KEY']   = 'junk'
        ENV['SIS_ENROLLMENT_UPDATE_ENDPOINT']  = 'junk'
        ENV['SIS_UNIT_GRADE_ENDPOINT_API_KEY'] = 'hunk'
        ENV['SIS_UNIT_GRADE_ENDPOINT']         = 'junk'

        allow(SettingsService).to receive(:get_settings).and_return({})
        allow(PipelineService::HTTPClient).to receive(:post)
        allow(PipelineService::Events::HTTPClient).to receive(:post)
        allow(SettingsService).to receive(:get_settings).and_return('enable_unit_grade_calculations' => true)
        allow(UnitsService::Queries::GetEnrollment).to receive(:query).and_return(@enrollment)
      end

      let(:assignment) {Assignment.create}
      let(:content_tag) {ContentTag.create(content: assignment)}
      let(:context_module) {ContextModule.create(content_tags: [content_tag])}
      let(:course) {Course.create(context_modules: [context_module])}

      it 'wont send if there is no change to the score' do
        expect(PipelineService::Events::HTTPClient).to_not receive(:post)

        course_with_student_submissions
      end

      context 'setting disabled' do
        it 'wont fire' do
          expect(SettingsService).to receive(:get_settings).and_return('enable_unit_grade_calculations' => false)
          expect(PipelineService::Events::HTTPClient).to_not receive(:post)

          course_with_student_submissions(submission_points: 50)
        end
      end
    end
  end
end
