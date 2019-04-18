require_relative '../../../rails_helper'

RSpec.describe UnitsService::Queries::GetEnrollment do
  subject { described_class }
  let(:course) { Course.create }
  let(:user) { User.create }
  let!(:enrollment) { Enrollment.create!(course: course, user: user)}
  describe '#query' do
    it '' do
      result = subject.query(course: course, user: user)
      expect(result.course_id).to eq(course.id)
      expect(result.user_id).to eq(user.id)
    end
  end
end
