class API::V1::Offering
  include Virtus.model

  class OfferingStudent
    include Virtus.model
    attribute :name, String
    attribute :username, String
    attribute :user_id, Integer
    attribute :started_activity, Boolean
    attribute :endpoint_url, String

    def initialize(student, offering, protocol, host_with_port)
      self.name = student.user.name
      self.username = student.user.login
      self.user_id = student.user.id
      learner = offering.learners.where(student_id: student.id).first
      # Learner object is available only if student has started the activity.
      self.started_activity = learner ? true : false
      self.endpoint_url = learner ? learner.remote_endpoint_url : nil
    end
  end

  attribute :teacher, String
  attribute :clazz, String
  attribute :clazz_id, Integer
  attribute :clazz_info_url, String
  attribute :activity, String
  attribute :activity_url, String
  attribute :students, Array[OfferingStudent]

  def initialize(offering, protocol, host_with_port)
    self.teacher = offering.clazz.teacher.name
    self.clazz = offering.clazz.name
    self.clazz_id = offering.clazz.id
    self.clazz_info_url = offering.clazz.class_info_url(protocol, host_with_port)
    self.activity = offering.name
    self.activity_url = offering.runnable.respond_to?(:url) ? offering.runnable.url : nil
    self.students = offering.clazz.students.map { |s| OfferingStudent.new(s, offering, protocol, host_with_port) }
  end
end
