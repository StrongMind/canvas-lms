module EnrollmentsHelper
  # Expected type format
  # StudentEnrollment, TeacherEnrollment, TaEnrollment, ObserverEnrollment, DesignerEnrollment
  #
  def enrollment_name(enrollment)
    klass = enrollment.type
    klass.slice(0, klass.index('E'))
  end
end