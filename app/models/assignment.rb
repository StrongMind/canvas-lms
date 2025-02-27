#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require 'atom'
require 'set'
require 'canvas/draft_state_validations'
require 'bigdecimal'
require_dependency 'turnitin'
require_dependency 'vericite'

class Assignment < ActiveRecord::Base
  include Workflow
  include TextHelper
  include HasContentTags
  include CopyAuthorizedLinks
  include Mutable
  include ContextModuleItem
  include DatesOverridable
  include SearchTermHelper
  include Canvas::DraftStateValidations
  include TurnitinID
  include Plannable
  include DuplicatingObjects

  POINTED_GRADING_TYPES = %w(percent letter_grade gpa_scale points).freeze
  NON_POINTED_GRADING_TYPES = %w(pass_fail not_graded).freeze
  ALLOWED_GRADING_TYPES = (POINTED_GRADING_TYPES + NON_POINTED_GRADING_TYPES).freeze

  OFFLINE_SUBMISSION_TYPES = %i(on_paper external_tool none not_graded wiki_page).freeze
  SUBMITTABLE_TYPES = %w(online_quiz discussion_topic wiki_page).freeze

  attr_accessor :previous_id, :updating_user, :copying, :user_submitted

  attr_reader :assignment_changed

  include MasterCourses::Restrictor
  restrict_columns :content, [:title, :description]
  restrict_assignment_columns

  has_many :submissions, -> { active }
  has_many :all_submissions, class_name: 'Submission', dependent: :destroy
  has_many :provisional_grades, :through => :submissions
  has_many :attachments, :as => :context, :inverse_of => :context, :dependent => :destroy
  has_many :assignment_student_visibilities
  has_one :quiz, class_name: 'Quizzes::Quiz'
  belongs_to :assignment_group
  has_one :discussion_topic, -> { where(root_topic_id: nil).order(:created_at) }
  has_one :wiki_page
  has_many :learning_outcome_alignments, -> { where("content_tags.tag_type='learning_outcome' AND content_tags.workflow_state<>'deleted'").preload(:learning_outcome) }, as: :content, inverse_of: :content, class_name: 'ContentTag'
  has_one :rubric_association, -> { where(purpose: 'grading').order(:created_at).preload(:rubric) }, as: :association, inverse_of: :association_object
  has_one :rubric, :through => :rubric_association
  has_one :teacher_enrollment, -> { preload(:user).where(enrollments: { workflow_state: 'active', type: 'TeacherEnrollment' }) }, class_name: 'TeacherEnrollment', foreign_key: 'course_id', primary_key: 'context_id'
  has_many :ignores, :as => :asset
  has_many :moderated_grading_selections, class_name: 'ModeratedGrading::Selection'
  belongs_to :context, polymorphic: [:course]
  belongs_to :grading_standard
  belongs_to :group_category

  has_many :assignment_configuration_tool_lookups, dependent: :delete_all
  has_many :tool_settings_context_external_tools, through: :assignment_configuration_tool_lookups, source: :tool, source_type: 'ContextExternalTool'

  has_one :external_tool_tag, :class_name => 'ContentTag', :as => :context, :inverse_of => :context, :dependent => :destroy
  validates_associated :external_tool_tag, :if => :external_tool?
  validate :group_category_changes_ok?
  validate :due_date_ok?, :unless => :active_assignment_overrides?
  validate :assignment_overrides_due_date_ok?
  validate :discussion_group_ok?
  validate :positive_points_possible?
  validate :moderation_setting_ok?
  validate :assignment_name_length_ok?
  validates :lti_context_id, presence: true, uniqueness: true

  accepts_nested_attributes_for :external_tool_tag, :update_only => true, :reject_if => proc { |attrs|
    # only accept the url, content_tyupe, content_id, and new_tab params, the other accessible
    # params don't apply to an content tag being used as an external_tool_tag
    content = case attrs['content_type']
              when 'Lti::MessageHandler', 'lti/message_handler'
                Lti::MessageHandler.find(attrs['content_id'].to_i)
              when 'ContextExternalTool', 'context_external_tool'
                ContextExternalTool.find(attrs['content_id'].to_i)
              end
    attrs[:content] = content if content
    attrs.slice!(:url, :new_tab, :content)
    false
  }
  before_validation do |assignment|
    assignment.lti_context_id ||= SecureRandom.uuid
    if assignment.external_tool? && assignment.external_tool_tag
      assignment.external_tool_tag.context = assignment
      assignment.external_tool_tag.content_type ||= "ContextExternalTool"
    else
      assignment.association(:external_tool_tag).reset
    end
    true
  end

  def positive_points_possible?
    return if self.points_possible.to_i >= 0
    return unless self.points_possible_changed?
    errors.add(
      :points_possible,
      I18n.t(
        "invalid_points_possible",
        "The value of possible points for this assignment must be zero or greater."
      )
    )
  end

  def get_potentially_conflicting_titles(title_base)
    assignment_titles = Assignment.active.for_course(self.context_id)
      .starting_with_title(title_base).pluck("title").to_set
    if self.wiki_page
      wiki_titles = self.wiki_page.get_potentially_conflicting_titles(title_base)
    else
      wiki_titles = [].to_set
    end
    assignment_titles.union(wiki_titles)
  end

  # The relevant associations that are copied are:
  #
  # learning_outcome_alignments, rubric_association, wiki_page
  #
  # In the case of wiki_page, a new wiki_page will be created.  The underlying
  # rubric association, however, will simply point to the original rubric
  # rather than copying the rubric.
  #
  # Other has_ relations are not duplicated for various reasons.
  # These are:
  #
  # attachments, submissions, provisional_grades, lti stuff, discussion_topic
  # ignores, moderated_grading_selections, teacher_enrollment
  # TODO: Try to get more of that stuff duplicated
  def duplicate(opts = {})
    # Don't clone a new record
    return self if self.new_record?

    default_opts = {
      :duplicate_wiki_page => true,
      :copy_title => nil
    }
    opts_with_default = default_opts.merge(opts)

    result = self.clone
    result.migration_id = nil
    result.all_submissions.clear
    result.attachments.clear
    result.ignores.clear
    result.moderated_grading_selections.clear
    result.lti_context_id = nil
    result.turnitin_id = nil
    result.discussion_topic = nil
    result.peer_review_count = 0
    result.workflow_state = "unpublished"
    # Default to the last position of all active assignments in the group.  Clients can still
    # override later.  Just helps to avoid duplicate positions.
    result.position = Assignment.active.where(assignment_group: assignment_group).maximum(:position) + 1
    result.title =
      opts_with_default[:copy_title] ? opts_with_default[:copy_title] : get_copy_title(self, t("Copy"))

    if self.wiki_page
      if opts_with_default[:duplicate_wiki_page]
        result.wiki_page = self.wiki_page.duplicate({
          :duplicate_assignment => false,
          :copy_title => result.title
        })
      end
    end
    # Learning outcome alignments seem to get copied magically, possibly
    # through the rubric
    result.rubric_association = self.rubric_association.clone
    result
  end

  def group_category_changes_ok?
    return if new_record?
    return unless has_submitted_submissions?
    if group_category_id_changed?
      errors.add :group_category_id, I18n.t("group_category_locked",
                                            "The group category can't be changed because students have already submitted on this assignment")
    end
  end

  def due_date_required?
    AssignmentUtil.due_date_required?(self)
  end

  def max_name_length
    if AssignmentUtil.assignment_name_length_required?(self)
      return AssignmentUtil.assignment_max_name_length(context)
    end
    Assignment.maximum_string_length
  end

  def secure_params
    body = {}
    body[:lti_assignment_id] = self.lti_context_id || SecureRandom.uuid
    Canvas::Security.create_jwt(body)
  end

  def discussion_group_ok?
    return unless new_record? || group_category_id_changed?
    return unless group_category_id && submission_types == 'discussion_topic'
    errors.add :group_category_id, I18n.t("discussion_group_category_locked",
      "Group categories cannot be set directly on a discussion assignment, but should be set on the discussion instead")
  end

  def provisional_grades_exist?
    return false unless moderated_grading? || moderated_grading_changed?
    ModeratedGrading::ProvisionalGrade
      .where(submission_id: self.submissions.having_submission.select(:id))
      .where('score IS NOT NULL').exists?
  end

  def graded_submissions_exist?
    return false unless graded?
    (graded_count > 0) || provisional_grades_exist?
  end

  def moderation_setting_ok?
    if moderated_grading_changed? && graded_submissions_exist?
      errors.add :moderated_grading, I18n.t("Moderated grading setting cannot be changed if graded submissions exist")
    end
    if (moderated_grading_changed? || new_record?) && moderated_grading?
      if !graded?
        errors.add :moderated_grading, I18n.t("Moderated grading setting cannot be enabled for ungraded assignments")
      end
      if has_group_category?
        errors.add :moderated_grading, I18n.t("Moderated grading setting cannot be enabled for group assignments")
      end
      if peer_reviews
        errors.add :moderated_grading, I18n.t("Moderated grading setting cannot be enabled for peer reviewed assignments")
      end
    end
  end

  API_NEEDED_FIELDS = %w(
    id
    title
    context_id
    context_type
    position
    points_possible
    grading_type
    due_at
    description
    lock_at
    unlock_at
    assignment_group_id
    peer_reviews
    anonymous_peer_reviews
    automatic_peer_reviews
    peer_reviews_due_at
    peer_review_count
    intra_group_peer_reviews
    submission_types
    group_category_id
    grade_group_students_individually
    turnitin_enabled
    vericite_enabled
    turnitin_settings
    allowed_extensions
    muted
    could_be_locked
    freeze_on_copy
    copied
    all_day
    all_day_date
    created_at
    updated_at
    post_to_sis
    integration_data
    integration_id
    only_visible_to_overrides
    moderated_grading
    grades_published_at
    omit_from_final_grade
    grading_standard_id
  )

  def context_tag_id
    if context_module_tags.loaded?
      context_module_tags.first&.id
    elsif context_module_tags
      context_module_tags.first.id unless context_module_tags.first.nil?
    end
  end
  def external_tool?
    self.submission_types == 'external_tool'
  end

  validates_presence_of :context_id, :context_type, :workflow_state

  validates_presence_of :title, if: :title_changed?
  validates_length_of :description, :maximum => maximum_long_text_length, :allow_nil => true, :allow_blank => true
  validates_length_of :allowed_extensions, :maximum => maximum_long_text_length, :allow_nil => true, :allow_blank => true
  validate :frozen_atts_not_altered, :if => :frozen?, :on => :update
  validates :grading_type, inclusion: { in: ALLOWED_GRADING_TYPES },
    allow_nil: true, on: :create

  acts_as_list :scope => :assignment_group
  simply_versioned :keep => 5
  sanitize_field :description, CanvasSanitize::SANITIZE
  copy_authorized_links( :description) { [self.context, nil] }

  def root_account
    context && context.root_account
  end

  def name
    self.title
  end

  def name=(val)
    self.title = val
  end

  serialize :integration_data, Hash

  serialize :turnitin_settings, Hash
  # file extensions allowed for online_upload submission
  serialize :allowed_extensions, Array

  def allowed_extensions=(new_value)
    # allow both comma and whitespace as separator
    new_value = new_value.split(/[\s,]+/) if new_value.is_a?(String)

    # remove the . if they put it on, and extra whitespace
    new_value.map! { |v| v.strip.gsub(/\A\./, '').downcase } if new_value.is_a?(Array)

    write_attribute(:allowed_extensions, new_value)
  end

  before_save :ensure_post_to_sis_valid,
              :infer_grading_type,
              :process_if_quiz,
              :default_values,
              :maintain_group_category_attribute,
              :validate_assignment_overrides


  after_save  :update_submissions_and_grades_if_details_changed,
              :update_grading_period_grades,
              :touch_assignment_group,
              :touch_context,
              :update_grading_standard,
              :update_submittable,
              :update_submissions_later,
              :schedule_do_auto_peer_review_job_if_automatic_peer_review,
              :delete_empty_abandoned_children,
              :update_cached_due_dates,
              :apply_late_policy,
              :touch_submissions_if_muted_changed

  has_a_broadcast_policy

  after_save :remove_assignment_updated_flag # this needs to be after has_a_broadcast_policy for the message to be sent

  def validate_assignment_overrides(opts={})
    if opts[:force_override_destroy] || group_category_id_changed?
      # needs to be .each(&:destroy) instead of .update_all(:workflow_state =>
      # 'deleted') so that the override gets versioned properly
      active_assignment_overrides.
        where(:set_type => 'Group').
        each { |o|
          o.dont_touch_assignment = true
          o.destroy
        }
    end

    AssignmentOverrideStudent.clean_up_for_assignment(self)
  end

  def schedule_do_auto_peer_review_job_if_automatic_peer_review
    return unless needs_auto_peer_reviews_scheduled?

    reviews_due_at = self.peer_reviews_assign_at || self.due_at
    return if reviews_due_at.blank?

    self.send_later_enqueue_args(:do_auto_peer_review, {
      :run_at => reviews_due_at,
      :singleton => Shard.birth.activate { "assignment:auto_peer_review:#{self.id}" }
    })
  end

  attr_accessor :skip_schedule_peer_reviews
  alias_method :skip_schedule_peer_reviews?, :skip_schedule_peer_reviews
  def needs_auto_peer_reviews_scheduled?
    !skip_schedule_peer_reviews? && peer_reviews? && automatic_peer_reviews? && !peer_reviews_assigned?
  end

  def do_auto_peer_review
    assign_peer_reviews if needs_auto_peer_reviews_scheduled? && overdue?
  end

  def touch_assignment_group
    if assignment_group_id_changed? && assignment_group_id_was.present?
      AssignmentGroup.where(id: assignment_group_id_was).update_all(updated_at: Time.zone.now.utc)
    end
    AssignmentGroup.where(:id => self.assignment_group_id).update_all(:updated_at => Time.zone.now.utc) if self.assignment_group_id
    true
  end

  def update_student_submissions
    graded_at = Time.zone.now
    submissions.graded.preload(:user).find_each do |s|
      if grading_type == 'pass_fail' && ['complete', 'pass'].include?(s.grade)
        s.score = points_possible
      end
      s.grade = score_to_grade(s.score, s.grade)
      s.graded_at = graded_at
      s.assignment = self
      s.assignment_changed_not_sub = true

      # Skip the grade calculation for now. We'll do it at the end.
      s.skip_grade_calc = true
      s.with_versioning(:explicit => true) { s.save! }
    end

    context.recompute_student_scores
  end

  def needs_to_update_submissions?
    !new_record? &&
      (points_possible_changed? || grading_type_changed? || grading_standard_id_changed?) &&
      !submissions.graded.empty?
  end
  private :needs_to_update_submissions?

  # if a teacher changes the settings for an assignment and students have
  # already been graded, then we need to update the "grade" column to
  # reflect the changes
  def update_submissions_and_grades_if_details_changed
    if needs_to_update_submissions?
      send_later_if_production(:update_student_submissions)
    else
      update_grades_if_details_changed
    end
    true
  end

  def needs_to_recompute_grade?
    !new_record? && (
      points_possible_changed? ||
      muted_changed? ||
      workflow_state_changed? ||
      assignment_group_id_changed? ||
      only_visible_to_overrides_changed? ||
      omit_from_final_grade_changed?
    )
  end
  private :needs_to_recompute_grade?

  def update_grades_if_details_changed
    if needs_to_recompute_grade?
      Rails.logger.info "GRADES: recalculating because assignment #{global_id} changed. (#{changes.inspect})"
      self.class.connection.after_transaction_commit { self.context.recompute_student_scores }
    end
    true
  end
  private :update_grades_if_details_changed

  def update_grading_period_grades
    return true unless due_at_changed? && !id_changed? && context.grading_periods?

    grading_period_was = GradingPeriod.for_date_in_course(date: due_at_was, course: context)
    grading_period = GradingPeriod.for_date_in_course(date: due_at, course: context)
    return true if grading_period_was&.id == grading_period&.id

    if grading_period_was
      # recalculate just the old grading period's score
      context.recompute_student_scores(grading_period_id: grading_period_was, update_course_score: false)
    end

    unless needs_to_recompute_grade? || needs_to_update_submissions?
      # recalculate the new grading period's score. If the grading period group is
      # weighted, then we need to recalculate the overall course score too. (If
      # grading period is nil, make sure we pass true for `update_course_score`
      # so we can use a singleton job.)
      context.recompute_student_scores(
        grading_period_id: grading_period,
        update_course_score: !grading_period || grading_period.grading_period_group&.weighted?
      )
    end
    true
  end
  private :update_grading_period_grades

  def create_in_turnitin
    return false unless self.context.turnitin_settings
    return true if self.turnitin_settings[:current]
    turnitin = Turnitin::Client.new(*self.context.turnitin_settings)
    res = turnitin.createOrUpdateAssignment(self, self.turnitin_settings)

    # make sure the defaults get serialized
    self.turnitin_settings = turnitin_settings

    if res[:assignment_id]
      self.turnitin_settings[:created] = true
      self.turnitin_settings[:current] = true
      self.turnitin_settings.delete(:error)
    else
      self.turnitin_settings[:error] = res
    end
    self.save
    return self.turnitin_settings[:current]
  end

  def turnitin_settings settings=nil
    if super().empty?
      # turnitin settings are overloaded for all plagiarism services as requested, so
      # alternative services can send in their own default settings, otherwise,
      # default to Turnitin settings
      if settings.nil?
        settings = Turnitin::Client.default_assignment_turnitin_settings
        default_originality = course.turnitin_originality if course
        settings[:originality_report_visibility] = default_originality if default_originality
      end
      settings
    else
      super()
    end
  end

  def turnitin_settings=(settings)
    if vericite_enabled?
      settings = VeriCite::Client.normalize_assignment_vericite_settings(settings)
    else
      settings = Turnitin::Client.normalize_assignment_turnitin_settings(settings)
    end
    unless settings.blank?
      [:created, :error].each do |key|
        settings[key] = self.turnitin_settings[key] if self.turnitin_settings[key]
      end
    end
    write_attribute :turnitin_settings, settings
  end

  def create_in_vericite
    return false unless Canvas::Plugin.find(:vericite).try(:enabled?)
    return true if self.turnitin_settings[:current] && self.turnitin_settings[:vericite]
    vericite = VeriCite::Client.new()
    res = vericite.createOrUpdateAssignment(self, self.turnitin_settings)

    # make sure the defaults get serialized
    self.turnitin_settings = turnitin_settings

    if res[:assignment_id]
      self.turnitin_settings[:created] = true
      self.turnitin_settings[:current] = true
      self.turnitin_settings[:vericite] = true
      self.turnitin_settings.delete(:error)
    else
      self.turnitin_settings[:error] = res
    end
    self.save
    return self.turnitin_settings[:current]
  end

  def vericite_settings
    self.turnitin_settings(VeriCite::Client.default_assignment_vericite_settings)
  end

  def vericite_settings=(settings)
    settings = VeriCite::Client.normalize_assignment_vericite_settings(settings)
    unless settings.blank?
      [:created, :error].each do |key|
        settings[key] = self.turnitin_settings[key] if self.turnitin_settings[key]
      end
    end
    write_attribute :turnitin_settings, settings
  end

  def self.all_day_interpretation(opts={})
    if opts[:due_at]
      if opts[:due_at] == opts[:due_at_was]
        # (comparison is modulo time zone) no real change, leave as was
        return opts[:all_day_was], opts[:all_day_date_was]
      else
        # 'normal' case. compare due_at to fancy midnight and extract its
        # date-part
        return (opts[:due_at].strftime("%H:%M") == '23:59'), opts[:due_at].to_date
      end
    else
      # no due at = all_day and all_day_date are irrelevant
      return false, nil
    end
  end

  def ensure_post_to_sis_valid
    self.post_to_sis = false unless gradeable?
    true
  end
  private :ensure_post_to_sis_valid

  def default_values
    raise "Assignments can only be assigned to Course records" if self.context_type && self.context_type != "Course"
    self.context_code = "#{self.context_type.underscore}_#{self.context_id}"
    self.title ||= (self.assignment_group.default_assignment_name rescue nil) || "Assignment"

    self.infer_all_day

    if !self.assignment_group || (self.assignment_group.deleted? && !self.deleted?)
      ensure_assignment_group(false)
    end
    self.submission_types ||= "none"
    self.peer_reviews_assign_at = [self.due_at, self.peer_reviews_assign_at].compact.max
    # have to use peer_reviews_due_at here because it's the column name
    self.peer_reviews_assigned = false if peer_reviews_due_at_changed?
    self.points_possible = nil unless self.graded?
    [
      :all_day, :could_be_locked, :grade_group_students_individually,
      :anonymous_peer_reviews, :turnitin_enabled, :vericite_enabled,
      :moderated_grading, :omit_from_final_grade, :freeze_on_copy,
      :copied, :only_visible_to_overrides, :post_to_sis, :peer_reviews_assigned,
      :peer_reviews, :automatic_peer_reviews, :muted, :intra_group_peer_reviews
    ].each { |attr| self[attr] = false if self[attr].nil? }
  end
  protected :default_values

  def ensure_assignment_group(do_save = true)
    self.context.require_assignment_group
    assignment_groups = self.context.assignment_groups.active
    if !assignment_groups.map(&:id).include?(self.assignment_group_id)
      self.assignment_group = assignment_groups.first
      save! if do_save
    end
  end

  def attendance?
    submission_types == 'attendance'
  end

  def due_date
    self.all_day ? self.all_day_date : self.due_at
  end

  def delete_empty_abandoned_children
    if submission_types_changed?
      each_submission_type do |submittable, type|
        unless self.submission_types == type.to_s
          submittable.unlink!(:assignment) if submittable
        end
      end
    end
  end

  def update_submissions_later
    send_later_if_production(:update_submissions) if points_possible_changed?
  end

  attr_accessor :updated_submissions # for testing
  def update_submissions
    @updated_submissions ||= []
    Submission.suspend_callbacks(:update_assignment, :touch_graders) do
      self.submissions.find_each do |submission|
        @updated_submissions << submission
        submission.save!
      end
    end
    context.touch_admins if context.respond_to?(:touch_admins)
  end

  def update_submittable
    return true if self.deleted?
    if self.submission_types == "online_quiz" && @saved_by != :quiz
      quiz = Quizzes::Quiz.where(assignment_id: self).first || self.context.quizzes.build
      quiz.assignment_id = self.id
      quiz.title = self.title
      quiz.description = self.description
      quiz.due_at = self.due_at
      quiz.unlock_at = self.unlock_at
      quiz.lock_at = self.lock_at
      quiz.points_possible = self.points_possible
      quiz.assignment_group_id = self.assignment_group_id
      quiz.workflow_state = 'created' if quiz.deleted?
      quiz.saved_by = :assignment
      quiz.workflow_state = published? ? 'available' : 'unpublished'
      quiz.save if quiz.changed?
    elsif self.submission_types == "discussion_topic" && @saved_by != :discussion_topic
      topic = self.discussion_topic || self.context.discussion_topics.build(:user => @updating_user)
      topic.message = self.description
      save_submittable(topic)
      self.discussion_topic = topic
    elsif self.context.feature_enabled?(:conditional_release) &&
      self.submission_types == "wiki_page" && @saved_by != :wiki_page
      page = self.wiki_page || self.context.wiki_pages.build(:user => @updating_user)
      save_submittable(page)
      self.wiki_page = page
    end
  end
  attr_writer :saved_by

  def save_submittable(submittable)
    submittable.assignment_id = self.id
    submittable.title = self.title
    submittable.saved_by = :assignment
    submittable.updated_at = Time.zone.now
    submittable.workflow_state = 'active' if submittable.deleted?
    submittable.workflow_state = published? ? 'active' : 'unpublished'
    submittable.save
  end
  protected :save_submittable

  def update_grading_standard
    self.grading_standard.save! if self.grading_standard
  end

  def all_context_module_tags
    all_tags = context_module_tags.to_a
    each_submission_type do |submission, _, short_type|
      all_tags.concat(submission.context_module_tags) if self.send("#{short_type}?")
    end
    all_tags
  end

  def context_module_action(user, action, points=nil)
    all_context_module_tags.each { |tag| tag.context_module_action(user, action, points) }
  end

  def recalculate_module_progressions
    # recalculate the module progressions now that the assignment is unmuted
    tags = all_context_module_tags
    return unless tags.any?
    modules = ContextModule.where(:id => tags.map(&:context_module_id)).order(:position).to_a.select do |mod|
      mod.completion_requirements && mod.completion_requirements.any?{|req| req[:type] == 'min_score' && tags.map(&:id).include?(req[:id])}
    end
    return unless modules.any?
    student_ids = self.submissions.having_submission.distinct.pluck(:user_id)
    return unless student_ids.any?

    modules.each do |mod|
      if mod.context_module_progressions.where(current: true, user_id: student_ids).update_all(current: false) > 0
        mod.send_later_if_production_enqueue_args(:evaluate_all_progressions, {:strand => "module_reeval_#{mod.global_context_id}"})
      end
    end
  end

  def touch_submissions_if_muted_changed
    if muted_changed?
      self.class.connection.after_transaction_commit do
        # this is necessary to generate new permissions cache keys for students
        submissions.touch_all

        # this ensures live events notifications
        submissions.in_workflow_state('graded').each(&:assignment_muted_changed)

        self.send_later_if_production(:recalculate_module_progressions) unless self.muted?
      end
    end
  end

  # call this to perform notifications on an Assignment that is not being saved
  # (useful when a batch of overrides associated with a new assignment have been saved)
  def do_notifications!(prior_version=nil, notify=false)
    # TODO: this will blow up if the group_category string is set on the
    # previous version, because it gets confused between the db string field
    # and the association.  one more reason to drop the db column
    prior_version ||= self.versions.previous(self.current_version.number).try(:model)
    self.notify_of_update = notify || false
    broadcast_notifications(prior_version || dup)
    remove_assignment_updated_flag
  end

  set_broadcast_policy do |p|
    p.dispatch :assignment_due_date_changed
    p.to { |assignment|
      # everyone who is _not_ covered by an assignment override affecting due_at
      # (the AssignmentOverride records will take care of notifying those users)
      excluded_ids = participants_with_overridden_due_at.map(&:id).to_set
      BroadcastPolicies::AssignmentParticipants.new(assignment, excluded_ids).to
    }
    p.whenever { |assignment|
      BroadcastPolicies::AssignmentPolicy.new(assignment).
        should_dispatch_assignment_due_date_changed?
    }

    p.dispatch :assignment_changed
    p.to { |assignment|
      BroadcastPolicies::AssignmentParticipants.new(assignment).to
    }
    p.whenever { |assignment|
      BroadcastPolicies::AssignmentPolicy.new(assignment).
        should_dispatch_assignment_changed?
    }

    p.dispatch :assignment_created
    p.to { |assignment|
      BroadcastPolicies::AssignmentParticipants.new(assignment).to
    }
    p.whenever { |assignment|
      BroadcastPolicies::AssignmentPolicy.new(assignment).
        should_dispatch_assignment_created?
    }
    p.filter_asset_by_recipient { |assignment, user|
      assignment.overridden_for(user)
    }

    p.dispatch :assignment_unmuted
    p.to { |assignment|
      BroadcastPolicies::AssignmentParticipants.new(assignment).to
    }
    p.whenever { |assignment|
      BroadcastPolicies::AssignmentPolicy.new(assignment).
        should_dispatch_assignment_unmuted?
    }
  end

  def notify_of_update=(val)
    @assignment_changed = Canvas::Plugin.value_to_boolean(val)
  end

  def notify_of_update
    false
  end

  def remove_assignment_updated_flag
    @assignment_changed = false
    true
  end

  def points_uneditable?
    (self.submission_types == 'online_quiz') # && self.quiz && (self.quiz.edited? || self.quiz.available?))
  end

  workflow do
    state :published do
      event :unpublish, :transitions_to => :unpublished
    end
    state :unpublished do
      event :publish, :transitions_to => :published
    end
    state :deleted
  end

  alias_method :destroy_permanently!, :destroy
  def destroy
    self.workflow_state = 'deleted'
    ContentTag.delete_for(self)
    self.rubric_association.destroy if self.rubric_association
    self.save!

    each_submission_type { |submission| submission.destroy if submission && !submission.deleted? }
    refresh_course_content_participation_counts
  end

  def refresh_course_content_participation_counts
    progress = self.context.progresses.build(tag: 'refresh_content_participation_counts')
    progress.save!
    progress.process_job(self.context, :refresh_content_participation_counts,
                         singleton: "refresh_content_participation_counts:#{context.global_id}")
  end

  def time_zone_edited
    CGI::unescapeHTML(read_attribute(:time_zone_edited) || "")
  end

  def restore(from=nil)
    self.workflow_state = self.has_student_submissions? ? "published" : "unpublished"
    self.save
    each_submission_type do |submission, _, short_type|
      submission.restore(:assignment) if from != short_type && submission
    end
    refresh_course_content_participation_counts
  end

  def participants_with_overridden_due_at
    Assignment.participants_with_overridden_due_at([self])
  end

  def self.participants_with_overridden_due_at(assignments)
    overridden_users = []

    AssignmentOverride.active.overriding_due_at.where(assignment_id: assignments).each do |o|
      overridden_users.concat(o.applies_to_students)
    end

    overridden_users.uniq!
    overridden_users
  end

  def students_with_visibility(scope=nil)
    scope ||= context.all_students.where("enrollments.workflow_state NOT IN ('inactive', 'rejected')")
    return scope unless self.differentiated_assignments_applies?
    scope.able_to_see_assignment_in_course_with_da(self.id, context.id)
  end

  attr_accessor :saved_by
  def process_if_quiz
    if self.submission_types == "online_quiz"
      self.points_possible = quiz.points_possible if quiz && quiz.available?
      copy_attrs = %w(due_at lock_at unlock_at)
      if quiz && @saved_by != :quiz &&
         copy_attrs.any? { |attr| changes[attr] }
        copy_attrs.each { |attr| quiz.send "#{attr}=", send(attr) }
        quiz.saved_by = :assignment
        quiz.save
      end
    end
  end
  protected :process_if_quiz

  def grading_scheme
    grading_standard_or_default.grading_scheme
  end

  def infer_grading_type
    self.grading_type = "pass_fail" if self.submission_types == "attendance"
    self.grading_type = "not_graded" if self.submission_types == "wiki_page"
    self.grading_type ||= "points"
  end

  def score_to_grade_percent(score=0.0)
    if points_possible && points_possible > 0
      result = score.to_f / self.points_possible
      (result * 100.0).round(2)
    else
      # there's not really any reasonable value we can set here -- if the
      # assignment is worth no points, any percentage is as valid as any other.
      score.to_f
    end
  end

  def grading_standard_or_default
    grading_standard ||
      context.default_grading_standard ||
      GradingStandard.default_instance
  end

  def score_to_grade(score=0.0, given_grade=nil)
    result = score.to_f
    case self.grading_type
    when "percent"
      result = "#{round_if_whole(score_to_grade_percent(score))}%"
    when "pass_fail"
      passed = if points_possible && points_possible > 0
                 score.to_f > 0
               elsif given_grade
                 given_grade == "complete" || given_grade == "pass"
               end
      result = passed ? "complete" : "incomplete"
    when "letter_grade", "gpa_scale"
      if self.points_possible.to_f > 0.0
        score = (BigDecimal.new(score.to_s.presence || '0.0') / BigDecimal.new(points_possible.to_s)).to_f
        result = grading_standard_or_default.score_to_grade(score * 100)
      elsif given_grade
        # the score for a zero-point letter_grade assignment could be considered
        # to be *any* grade, so look at what the current given grade is
        # instead of trying to calculate it
        result = given_grade
      else
        # there's not really any reasonable value we can set here -- if the
        # assignment is worth no points, and the grader didn't enter an
        # explicit letter grade, any letter grade is as valid as any other.
        result = grading_standard_or_default.score_to_grade(score.to_f)
      end
    end
    round_if_whole(result).to_s
  end

  def interpret_grade(grade)
    case grade.to_s
    when %r{%$}
      # interpret as a percentage
      percentage = grade.to_f / 100.0
      points_possible.to_f * percentage
    when %r{[\d\.]+}
      if grading_type == "gpa_scale"
        # if it matches something in a scheme, take that, else return nil
        return nil unless standard_based_score = grading_standard_or_default.grade_to_score(grade)
        (points_possible || 0.0) * standard_based_score / 100.0
      else
        # interpret as a numerical score
        grade.to_f
      end
    when "pass", "complete"
      points_possible.to_f
    when "fail", "incomplete"
      0.0
    else
      # try to treat it as a letter grade
      if uses_grading_standard && standard_based_score = grading_standard_or_default.grade_to_score(grade)
        (points_possible || 0.0) * standard_based_score / 100.0
      else
        nil
      end
    end
  end

  def grade_to_score(grade=nil)
    return nil if grade.blank?
    parsed_grade = interpret_grade(grade)
    case self.grading_type
    when "points", "percent", "letter_grade", "gpa_scale"
      score = parsed_grade
    when "pass_fail"
      # only allow full points or no points for pass_fail assignments
      score = case parsed_grade.to_f
      when points_possible
        points_possible
      when 0.0
        0.0
      else
        nil
      end
    when "not_graded"
      score = nil
    else
      raise "oops, we need to interpret a new grading_type. get coding."
    end
    score
  end

  def uses_grading_standard
    ["letter_grade", "gpa_scale"].include? grading_type
  end

  def infer_times
    # set the time to 11:59 pm in the creator's time zone, if none given
    self.due_at = CanvasTime.fancy_midnight(self.due_at)
    self.lock_at = CanvasTime.fancy_midnight(self.lock_at)
  end

  def infer_all_day
    # make the comparison to "fancy midnight" and the date-part extraction in
    # the time zone that was active during editing
    time_zone = (ActiveSupport::TimeZone.new(self.time_zone_edited) rescue nil) || Time.zone
    self.all_day, self.all_day_date = Assignment.all_day_interpretation(
      :due_at => self.due_at ? self.due_at.in_time_zone(time_zone) : nil,
      :due_at_was => self.due_at_was,
      :all_day_was => self.all_day_was,
      :all_day_date_was => self.all_day_date_was)
  end

  def to_atom(opts={})
    extend ApplicationHelper
    author_name = self.context.present? ? self.context.name : t('atom_no_author', "No Author")
    Atom::Entry.new do |entry|
      entry.title     = t(:feed_entry_title, "Assignment: %{assignment}", :assignment => self.title) unless opts[:include_context]
      entry.title     = t(:feed_entry_title_with_course, "Assignment, %{course}: %{assignment}", :assignment => self.title, :course => self.context.name) if opts[:include_context]
      entry.authors  << Atom::Person.new(:name => author_name)
      entry.updated   = self.updated_at.utc
      entry.published = self.created_at.utc
      entry.id        = "tag:#{HostUrl.default_host},#{self.created_at.strftime("%Y-%m-%d")}:/assignments/#{self.feed_code}_#{self.due_at.strftime("%Y-%m-%d-%H-%M") rescue "none"}"
      entry.links    << Atom::Link.new(:rel => 'alternate',
                                    :href => "http://#{HostUrl.context_host(self.context)}/#{context_url_prefix}/assignments/#{self.id}")
      entry.content   = Atom::Content::Html.new(before_label(:due, "Due") + " #{datetime_string(self.due_at, :due_date)}<br/>#{self.description}<br/><br/>
        <div>
          #{self.description}
        </div>
      ")
    end
  end

  def start_at
    due_at
  end

  def end_at
    due_at
  end

  def context_prefix
    context_url_prefix
  end

  def to_ics(in_own_calendar: true, preloaded_attachments: {}, user: nil)
    CalendarEvent::IcalEvent.new(self).to_ics(in_own_calendar:       in_own_calendar,
                                              preloaded_attachments: preloaded_attachments,
                                              include_description:   include_description?(user))
  end

  def include_description?(user, lock_info=nil)
    return unless user
    lock_info ||= self.locked_for?(user, :check_policies => true)
    !lock_info || (lock_info[:can_view] && !lock_info[:context_module])
  end

  def all_day
    read_attribute(:all_day) || (self.new_record? && !!self.due_at && (self.due_at.strftime("%H:%M") == '23:59' || self.due_at.strftime("%H:%M") == '00:00'))
  end

  def self.preload_context_module_tags(assignments, include_context_modules: false)
    module_tags_include =
      if include_context_modules
        { context_module_tags: :context_module }
      else
        :context_module_tags
      end

    ActiveRecord::Associations::Preloader.new.preload(assignments, [
      module_tags_include,
      :context, # necessary while wiki_page assignments behind feature flag
      { :discussion_topic => :context_module_tags },
      { :wiki_page => :context_module_tags },
      { :quiz => :context_module_tags }
    ])
  end

  def locked_for?(user, opts={})
    return false if opts[:check_policies] && context.grants_right?(user, :read_as_admin)
    Rails.cache.fetch(locked_cache_key(user), :expires_in => 1.minute) do
      locked = false
      assignment_for_user = self.overridden_for(user)
      if (assignment_for_user.unlock_at && assignment_for_user.unlock_at > Time.zone.now)
        locked = {:asset_string => assignment_for_user.asset_string, :unlock_at => assignment_for_user.unlock_at}
      elsif self.could_be_locked && item = locked_by_module_item?(user, opts)
        locked = {:asset_string => self.asset_string, :context_module => item.context_module.attributes}
      elsif (assignment_for_user.lock_at && assignment_for_user.lock_at < Time.zone.now)
        locked = {:asset_string => assignment_for_user.asset_string, :lock_at => assignment_for_user.lock_at, :can_view => true}
      else
        each_submission_type do |submission, _, short_type|
          next unless self.send("#{short_type}?")
          if submission_locked = submission.locked_for?(user, opts.merge(:skip_assignment => true))
            locked = submission_locked
          end
          break
        end
      end
      locked
    end
  end

  def clear_locked_cache(user)
    super
    each_submission_type do |submission, _, short_type|
      Rails.cache.delete(submission.locked_cache_key(user)) if self.send("#{short_type}?")
    end
  end

  def self.assignment_type?(type)
    %w(quiz attendance discussion_topic wiki_page external_tool).include? type.to_s
  end

  def self.get_submission_type(assignment_type)
    if assignment_type?(assignment_type)
      type = assignment_type.to_s
      type = "online_quiz" if type == "quiz"
      type = type.to_sym if assignment_type.is_a?(Symbol)
      type
    end
  end

  def submission_types_array
    (self.submission_types || "").split(",")
  end

  def submittable_type?
    submission_types && ![
      '',
      'none',
      'not_graded',
      'online_quiz',
      'discussion_topic',
      'wiki_page',
      'attendance',
      'external_tool'
    ].include?(self.submission_types)
  end

  def submittable_object
    case self.submission_types
    when 'online_quiz'
      self.quiz
    when 'discussion_topic'
      self.discussion_topic
    when 'wiki_page'
      self.wiki_page
    end
  end

  def each_submission_type
    if block_given?
      submittable_types = %i(discussion_topic quiz)
      submittable_types << :wiki_page if self.context.try(:feature_enabled?, :conditional_release)
      submittable_types.each do |asg_type|
        submittable = self.send(asg_type)
        yield submittable, Assignment.get_submission_type(asg_type), asg_type
      end
    end
  end

  def graded_count
    return read_attribute(:graded_count).to_i if read_attribute(:graded_count)
    Rails.cache.fetch(['graded_count', self].cache_key) do
      submissions.graded.in_workflow_state('graded').count
    end
  end

  def has_submitted_submissions?
    return @has_submitted_submissions unless @has_submitted_submissions.nil?
    submitted_count > 0
  end
  attr_writer :has_submitted_submissions

  def submitted_count
    return read_attribute(:submitted_count).to_i if read_attribute(:submitted_count)
    Rails.cache.fetch(['submitted_count', self].cache_key) do
      self.submissions.having_submission.count
    end
  end

  set_policy do
    given { |user, session| self.context.grants_right?(user, session, :read) && self.published? }
    can :read and can :read_own_submission

    given { |user, session|
      (submittable_type? || submission_types == "discussion_topic") &&
      context.grants_right?(user, session, :participate_as_student) &&
      !locked_for?(user) &&
      visible_to_user?(user) &&
      !excused_for?(user)
    }
    can :submit and can :attach_submission_comment_files

    given { |user, session| self.context.grants_right?(user, session, :read_as_admin) }
    can :read

    given { |user, session| self.context.grants_right?(user, session, :manage_grades) }
    can :grade and can :attach_submission_comment_files

    given { |user, session| self.context.grants_right?(user, session, :manage_assignments) }
    can :update and can :create and can :read and can :attach_submission_comment_files

    given do |user, session|
      self.context.grants_right?(user, session, :manage_assignments) &&
        (self.context.account_membership_allows(user) ||
         !in_closed_grading_period?)
    end
    can :delete
  end

  def user_can_read_grades?(user, session=nil)
    RequestCache.cache('user_can_read_grades', self, user, session) do
      self.context.grants_right?(user, session, :view_all_grades) ||
        (self.published? && self.context.grants_right?(user, session, :manage_grades))
    end
  end

  def filter_attributes_for_user(hash, user, session)
    if lock_info = self.locked_for?(user, :check_policies => true)
      hash.delete('description') unless include_description?(user, lock_info)
      hash['lock_info'] = lock_info
    end
  end

  def participants(opts={})
    return context.participants(include_observers: opts[:include_observers], excluded_user_ids: opts[:excluded_user_ids]) unless differentiated_assignments_applies?
    participants_with_visibility(opts)
  end

  def participants_with_visibility(opts={})
    users = context.participating_admins

    student_scope = students_with_visibility(context.participating_students_by_date)
    student_scope = student_scope.where.not(:id => opts[:excluded_user_ids]) if opts[:excluded_user_ids]
    applicable_students = student_scope.to_a
    users += applicable_students

    if opts[:include_observers]
      users += User.observing_students_in_course(applicable_students.map(&:id), self.context_id)
      users += User.observing_full_course(context.id)
    end

    users.uniq
  end

  def set_default_grade(options={})
    score = self.grade_to_score(options[:default_grade])
    grade = self.score_to_grade(score)
    submissions_to_save = []
    self.context.students.find_in_batches do |students|
      submissions = find_or_create_submissions(students)
      submissions_to_save.concat(submissions.select  { !submissions.score || (options[:overwrite_existing_grades] && submissions.score != score) })
    end

    Submission.active.where(id: submissions_to_save).update_all({
      :score => score,
      :grade => grade,
      :published_score => score,
      :published_grade => grade,
      :workflow_state => 'graded',
      :graded_at => Time.zone.now.utc
    }) unless submissions_to_save.empty?

    Rails.logger.info "GRADES: recalculating because assignment #{global_id} had default grade set (#{options.inspect})"
    self.context.recompute_student_scores
    student_ids = context.student_ids
    send_later_if_production(:multiple_module_actions, student_ids, :scored, score)
  end

  def title_with_id
    "#{title} (#{id})"
  end

  def title_slug
    CanvasTextHelper.truncate_text(title, :ellipsis => '')
  end

  def self.title_and_id(str)
    if str =~ /\A(.*)\s\((\d+)\)\z/
      [$1, $2]
    else
      [str, nil]
    end
  end

  def group_students(student)
    group = group_category.group_for(student) if has_group_category?
    students = if group
      group.users
        .joins(:enrollments)
        .where(:enrollments => { :course_id => self.context})
        .merge(Course.instance_exec(&Course.reflections['admin_visible_student_enrollments'].scope).only(:where))
        .order("users.id") # this helps with preventing deadlock with other things that touch lots of users
        .distinct
        .to_a
    else
      [student]
    end

    [group, students]
  end

  def multiple_module_actions(student_ids, action, points=nil)
    students = self.context.students.where(id: student_ids)
    students.each do |user|
      self.context_module_action(user, action, points)
    end
  end

  def submission_for_student(user)
    self.all_submissions.where(user_id: user.id).first_or_initialize
  end

  class GradeError < StandardError
    attr_accessor :status_code

    def initialize(message = nil, status_code = nil)
      super(message)
      self.status_code = status_code
    end
  end

  def compute_grade_and_score(grade, score)
    if grade
      score = self.grade_to_score(grade)
    end
    if score
      grade = self.score_to_grade(score, grade)
    end
    [grade, score]
  end

  def grade_student(original_student, opts={})
    raise GradeError.new("Student is required") unless original_student
    unless context.includes_user?(original_student, context.admin_visible_student_enrollments) # allows inactive users to be graded
      raise GradeError.new("Student must be enrolled in the course as a student to be graded")
    end
    raise GradeError.new("Grader must be enrolled as a course admin") if opts[:grader] && !self.context.grants_right?(opts[:grader], :manage_grades)

    opts[:excused] = Canvas::Plugin.value_to_boolean(opts.delete(:excuse)) if opts.key? :excuse
    raise GradeError.new("Cannot simultaneously grade and excuse an assignment") if opts[:excused] && (opts[:grade] || opts[:score])
    raise GradeError.new("Provisional grades require a grader") if opts[:provisional] && opts[:grader].nil?

    opts.delete(:id)
    group, students = group_students(original_student)
    submissions = []
    grade_group_students = !(grade_group_students_individually || opts[:excused])

    if grade_group_students
      find_or_create_submissions(students) do |submission|
        submissions << save_grade_to_submission(submission, original_student, group, opts)
      end
    else
      submission = find_or_create_submission(original_student)
      submissions << save_grade_to_submission(submission, original_student, group, opts)
    end

    submissions.compact
  end

  def tool_settings_resource_codes
    lookup = assignment_configuration_tool_lookups.first
    return {} unless lookup.present?
    lookup.resource_codes
  end

  def tool_settings_tool
    self.tool_settings_tools.first
  end

  def tool_settings_tool=(tool)
    self.tool_settings_tools = [tool] if tool_settings_tool != tool
  end

  def clear_tool_settings_tools
    assignment_configuration_tool_lookups.where(tool_type: 'Lti::MessageHandler').each(&:destroy_subscription)
    assignment_configuration_tool_lookups.clear
  end
  private :clear_tool_settings_tools

  def tool_settings_tools=(tools)
    clear_tool_settings_tools
    tools.each do |t|
      if t.instance_of? ContextExternalTool
        tool_settings_context_external_tools << t
      elsif t.instance_of? Lti::MessageHandler
        product_family = t.resource_handler.tool_proxy.product_family
        assignment_configuration_tool_lookups.new(
          tool_vendor_code: product_family.vendor_code,
          tool_product_code: product_family.product_code,
          tool_resource_type_code: t.resource_handler.resource_type_code,
          tool_type: 'Lti::MessageHandler'
        )
      end
    end
    tools
  end
  protected :tool_settings_tools=

  def tool_settings_tools
    tool_settings_context_external_tools + tool_settings_message_handlers
  end
  protected :tool_settings_tools

  def tool_settings_message_handlers
    assignment_configuration_tool_lookups.where(tool_type: 'Lti::MessageHandler').map(&:lti_tool)
  end
  private :tool_settings_message_handlers

  def save_grade_to_submission(submission, original_student, group, opts)
    unless submission.grader_can_grade?
      error_details = submission.grading_error_message
      raise GradeError.new("Cannot grade this submission at this time: #{error_details}", :forbidden)
    end

    submission.skip_grade_calc = opts[:skip_grade_calc]

    previously_graded = submission.grade.present? || submission.excused?
    return if previously_graded && opts[:dont_overwrite_grade]
    return if submission.user != original_student && submission.excused?

    grader = opts[:grader]
    grade, score = compute_grade_and_score(opts[:grade], opts[:score])

    did_grade = false
    submission.attributes = opts.slice(:excused, :submission_type, :url, :body)

    unless opts[:provisional]
      submission.grader = grader
      submission.grader_id = opts[:grader_id] if opts.key?(:grader_id)
      submission.grade = grade
      submission.score = score
      submission.graded_anonymously = opts[:graded_anonymously] if opts.key?(:graded_anonymously)
      submission.excused = false if score.present?
      did_grade = true if score.present? || submission.excused?
    end

    if did_grade
      submission.grade_matches_current_submission = true
      submission.instance_variable_set(:@regraded, true)
    end

    if (submission.score_changed? ||
        submission.grade_matches_current_submission) &&
        ((submission.score && submission.grade) || submission.excused?)
      submission.workflow_state = "graded"
    end
    submission.group = group
    submission.graded_at = Time.zone.now if did_grade
    previously_graded ? submission.with_versioning(:explicit => true) { submission.save! } : submission.save!

    if opts[:provisional]
      submission.find_or_create_provisional_grade!(grader,
        grade: grade,
        score: score,
        force_save: true,
        final: opts[:final],
        graded_anonymously: opts[:graded_anonymously]
      )
    end

    submission
  end
  private :save_grade_to_submission

  def find_or_create_submission(user)
    Assignment.unique_constraint_retry do
      s = all_submissions.where(user_id: user).first
      if !s
        s = submissions.build
        user.is_a?(User) ? s.user = user : s.user_id = user
        s.save!
      end
      s
    end
  end

  def find_or_create_submissions(students)
    submissions = self.all_submissions.where(user_id: students).order(:user_id).to_a
    submissions_hash = submissions.index_by(&:user_id)
    # we touch the user in an after_save; the FK causes a read lock
    # to be taken on the user during submission INSERT, so to avoid
    # deadlocks, we pre-lock the users
    needs_lock = false
    shard.activate do
      if Submission.connection.adapter_name == 'PostgreSQL' && Submission.connection.send(:postgresql_version) < 90300
        needs_lock = Submission.connection.open_transactions == 0
        # we're already in a transaction, and can lock everyone at once
        if !needs_lock
          missing_users = students.map(&:id) - submissions_hash.keys
          User.shard(shard).where(id: missing_users).order(:id).lock.pluck(:id)
        end
      end
    end
    students.each do |student|
      submission = submissions_hash[student.id]
      if !submission
        begin
          transaction(requires_new: true) do
            # lock just one user
            if needs_lock
              User.shard(shard).where(id: student).lock.pluck(:id)
            end
            submission = self.submissions.build(user: student)
            submission.assignment = self
            yield submission if block_given?
            submission.save! if submission.changed?
            submissions << submission
          end
        rescue ActiveRecord::RecordNotUnique
          submission = self.all_submissions.where(user_id: student).first
          raise unless submission
          submissions << submission
          submission.assignment = self
          submission.user = student
          yield submission if block_given?
        end
      else
        submission.assignment = self
        submission.user = student
        yield submission if block_given?
      end
    end
    submissions
  end

  def find_asset_for_assessment(association, user_or_user_id, opts={})
    user = user_or_user_id.is_a?(User) ? user_or_user_id : self.context.users.where(id: user_or_user_id).first
    if association.purpose == "grading"
      if user
        sub = self.find_or_create_submission(user)
        if opts[:provisional_grader]
          [sub.find_or_create_provisional_grade!(opts[:provisional_grader], final: opts[:final]), user]
        else
          [sub, user]
        end
      else
        [nil, nil]
      end
    else
      [self, user]
    end
  end

  # Update at this point is solely used for commenting on the submission
  def update_submission(original_student, opts={})
    raise "Student Required" unless original_student

    group, students = group_students(original_student)
    opts[:author] ||= opts[:commenter] || opts[:user_id].present? && User.find_by(id: opts[:user_id])
    res = []

    # Only teachers (those who can manage grades) can have hidden comments
    opts[:hidden] = muted? && self.context.grants_right?(opts[:author], :manage_grades) unless opts.key?(:hidden)

    if opts[:comment] && opts[:assessment_request]
      # if there is no rubric the peer review is complete with just a comment
      opts[:assessment_request].complete unless opts[:assessment_request].rubric_association
    end

    if opts[:comment] && Canvas::Plugin.value_to_boolean(opts[:group_comment])
      uuid = CanvasSlug.generate_securish_uuid
      res = find_or_create_submissions(students) do |submission|
        save_comment_to_submission(submission, group, opts, uuid)
      end
    else
      submission = find_or_create_submission(original_student)
      res << save_comment_to_submission(submission, group, opts)
    end
    res
  end

  def save_comment_to_submission(submission, group, opts, uuid = nil)
    submission.group = group
    submission.save! if submission.changed?
    opts[:group_comment_id] = uuid if group && uuid
    submission.add_comment(opts)
    submission.reload
  end
  private :save_comment_to_submission

  SUBMIT_HOMEWORK_ATTRS = %w[body url submission_type
                             media_comment_id media_comment_type]
  ALLOWABLE_SUBMIT_HOMEWORK_OPTS = (SUBMIT_HOMEWORK_ATTRS +
                                    %w[comment group_comment attachments]).to_set

  def submit_homework(original_student, opts={})
    # Only allow a few fields to be submitted.  Cannot submit the grade of a
    # homework assignment, for instance.
    opts.keys.each { |k|
      opts.delete(k) unless ALLOWABLE_SUBMIT_HOMEWORK_OPTS.include?(k.to_s)
    }
    raise "Student Required" unless original_student
    comment = opts.delete(:comment)
    group_comment = opts.delete(:group_comment)
    group, students = group_students(original_student)
    homeworks = []
    primary_homework = nil
    submitted = case opts[:submission_type]
                when "online_text_entry"
                  opts[:body].present?
                when "online_url", "basic_lti_launch"
                  opts[:url].present?
                when "online_upload"
                  opts[:attachments].size > 0
                else
                  true
                end
    transaction do
      find_or_create_submissions(students) do |homework|
        # clear out attributes from prior submissions
        if opts[:submission_type].present?
          SUBMIT_HOMEWORK_ATTRS.each { |attr| homework[attr] = nil }
          homework.late_policy_status = nil
          homework.seconds_late_override = nil
        end

        student = homework.user
        homework.grade_matches_current_submission = homework.score ? false : true
        homework.attributes = opts.merge({
          :attachment => nil,
          :processed => false,
          :process_attempts => 0,
          :workflow_state => submitted ? "submitted" : "unsubmitted",
          :group => group
        })
        homework.submitted_at = Time.zone.now

        homework.with_versioning(:explicit => (homework.submission_type != "discussion_topic")) do
          if group
            if student == original_student
              homework.broadcast_group_submission
            else
              homework.save_without_broadcasting!
            end
          else
            homework.save!
          end
        end
        homeworks << homework
        primary_homework = homework if student == original_student
      end
    end
    homeworks.each do |homework|
      context_module_action(homework.student, homework.workflow_state.to_sym)
      if comment && (group_comment || homework == primary_homework)
        hash = {:comment => comment, :author => original_student}
        hash[:group_comment_id] = CanvasSlug.generate_securish_uuid if group_comment && group
        homework.add_comment(hash)
      end
    end
    touch_context
    return primary_homework
  end

  def submissions_downloaded?
    self.submissions_downloads && self.submissions_downloads > 0
  end

  def serializable_hash(opts = {})
    super(opts.reverse_merge include_root: true)
  end

  def as_json(options={})
    json = super(options)
    if json && json['assignment']
      # remove anything coming automatically from deprecated db column
      json['assignment'].delete('group_category')
      if self.group_category
        # put back version from association
        json['assignment']['group_category'] = self.group_category.name
      elsif self.read_attribute('group_category').present?
        # or failing that, version from query
        json['assignment']['group_category'] = self.read_attribute('group_category')
      end
    end
    json
  end

  def grades_published?
    !moderated_grading? || grades_published_at.present?
  end

  def student_needs_provisional_grade?(student, preloaded_counts=nil)
    pg_count = if preloaded_counts
      preloaded_counts[student.id] || 0
    else
      self.provisional_grades.not_final.where(:submissions => {:user_id => student}).count
    end
    in_moderation_set = if self.moderated_grading_selections.loaded?
      self.moderated_grading_selections.detect{|s| s.student_id == student.id}.present?
    else
      self.moderated_grading_selections.where(:student_id => student).exists?
    end
    pg_count < (in_moderation_set ? 2 : 1)
  end

  def sections_with_visibility(user)
    return context.active_course_sections unless self.differentiated_assignments_applies?

    visible_student_ids = visible_students_for_speed_grader(user).map(&:id)
    context.active_course_sections.joins(:student_enrollments).
      where(:enrollments => {:user_id => visible_student_ids, :type => "StudentEnrollment"}).distinct.reorder("name")
  end

  # quiz submission versions are too expensive to de-serialize so we have to
  # cap the number we will do
  def too_many_qs_versions?(student_submissions)
    qs_threshold = Setting.get("too_many_quiz_submission_versions", "150").to_i
    qs_ids = student_submissions.map(&:quiz_submission_id).compact
    return false if qs_ids.empty?
    Version.shard(shard).from(Version.
        where(versionable_type: 'Quizzes::QuizSubmission', versionable_id: qs_ids).
        limit(qs_threshold)).count >= qs_threshold
  end

  # :including quiz submission versions won't work for records in the
  # database before namespace changes. This does a bulk pre-query to prevent
  # n+1 queries. replace this with an :include again after namespaced
  # polymorphic data is migrated
  def quiz_submission_versions(student_submissions, too_many_qs_versions)
    submissions_with_qs = student_submissions.select do |sub|
      quiz && sub.quiz_submission && !too_many_qs_versions
    end
    qs_versions = Version.where(versionable_type: 'Quizzes::QuizSubmission',
                                versionable_id: submissions_with_qs.map(&:quiz_submission)).
                          order(:number)

    qs_versions.each_with_object({}) do |version, hash|
      hash[version.versionable_id] ||= []
      hash[version.versionable_id] << version
    end
  end

  def grade_as_group?
    has_group_category? && !grade_group_students_individually?
  end

  # for group assignments, returns a single "student" for each
  # group's submission.  the students name will be changed to the group's
  # name.  for non-group assignments this just returns all visible users
  def representatives(user, includes: [:inactive])
    return visible_students_for_speed_grader(user, includes: includes) unless grade_as_group?

    submissions = self.submissions.preload(:user).to_a
    users_with_submissions = submissions.select(&:has_submission?).map(&:user)
    users_with_turnitin_data = if turnitin_enabled?
                                 submissions.reject { |s| s.turnitin_data.blank? }.map(&:user)
                               else
                                 []
                               end
    users_with_vericite_data = if vericite_enabled?
                                 submissions
                                 .reject { |s| s.turnitin_data.blank? }
                                 .map(&:user)
                               else
                                 []
                               end
    # this only includes users with a submission who are unexcused
    users_who_arent_excused = submissions.reject(&:excused?).map(&:user)

    enrollment_state =
      Hash[self.context.all_accepted_student_enrollments.pluck(:user_id, :workflow_state)]

    # prefer active over inactive, inactive over everything else
    enrollment_priority = { 'active' => 1, 'inactive' => 2 }
    enrollment_priority.default = 100

    reps_and_others = groups_and_ungrouped(user, includes: includes).map do |group_name, group_info|
      group_students = group_info[:users]
      visible_group_students =
        group_students & visible_students_for_speed_grader(user, includes: includes)

      candidate_students = visible_group_students & users_who_arent_excused
      candidate_students = visible_group_students if candidate_students.empty?
      candidate_students.sort_by! { |s| enrollment_priority[enrollment_state[s.id]] }

      representative   = (candidate_students & (users_with_turnitin_data || users_with_vericite_data)).first
      representative ||= (candidate_students & users_with_submissions).first
      representative ||= candidate_students.first
      others = visible_group_students - [representative]
      next unless representative

      representative.readonly!
      representative.name = group_name
      representative.sortable_name = group_info[:sortable_name]
      representative.short_name = group_name

      [representative, others]
    end.compact

    sorted_reps_with_others =
      Canvas::ICU.collate_by(reps_and_others) { |rep, _| rep.sortable_name }
    if block_given?
      sorted_reps_with_others.each { |r,o| yield r, o }
    end
    sorted_reps_with_others.map(&:first)
  end

  def groups_and_ungrouped(user, includes: [])
    groups_and_users = group_category.
      groups.active.preload(group_memberships: :user).
      map { |g| [g.name, { sortable_name: g.name, users: g.users}] }
    users_in_group = groups_and_users.flat_map { |_, group_info| group_info[:users] }
    groupless_users = visible_students_for_speed_grader(user, includes: includes) - users_in_group
    phony_groups = groupless_users.map do |u|
      sortable_name = users_in_group.empty? ? u.sortable_name : u.name
      [u.name, { sortable_name: sortable_name, users: [u] }]
    end
    groups_and_users + phony_groups
  end
  private :groups_and_ungrouped

  # using this method instead of students_with_visibility so we
  # can add the includes and students_visible_to/participating_students scopes
  def visible_students_for_speed_grader(user, includes: [:inactive])
    @visible_students_for_speed_grader ||= {}
    @visible_students_for_speed_grader[[user.global_id, includes]] ||= (
      student_scope = user ? context.students_visible_to(user, include: includes) : context.participating_students
      students_with_visibility(student_scope)
    ).order_by_sortable_name.distinct.to_a
  end

  def visible_rubric_assessments_for(user, opts={})
    return [] unless user && self.rubric_association

    scope = self.rubric_association.rubric_assessments.preload(:assessor)

    if opts[:provisional_grader]
      scope = scope.for_provisional_grades.where(:assessor_id => user.id)
    elsif opts[:provisional_moderator]
      scope = scope.for_provisional_grades
    else
      scope = scope.for_submissions
      unless self.rubric_association.grants_any_right?(user, :manage, :view_rubric_assessments)
        scope = scope.where(:assessor_id => user.id)
      end
    end
    scope.to_a.sort_by{|a| [a.assessment_type == 'grading' ? CanvasSort::First : CanvasSort::Last, Canvas::ICU.collation_key(a.assessor_name)] }
  end

  # Takes a zipped file full of assignment comments/annotated assignments
  # and generates comments on each assignment's submission.  Quietly
  # ignore (for now) files that don't make sense to us.  The convention
  # for file naming (how we're sending it down to the teacher) is
  # last_name_first_name_user_id_attachment_id.
  # extension
  def generate_comments_from_files(filename, commenter)
    zip_extractor = ZipExtractor.new(filename)
    # Creates a list of hashes, each one with a :user, :filename, and :submission entry.
    @ignored_files = []
    file_map = zip_extractor.unzip_files.map { |f| infer_comment_context_from_filename(f) }.compact
    files_for_user = file_map.group_by { |f| f[:user] }
    comments = files_for_user.map do |user, files|
      attachments = files.map { |g|
        FileInContext.attach(self, g[:filename], g[:display_name])
      }
      comment = {
        comment: t(:comment_from_files, {one: "See attached file", other: "See attached files"}, count: files.size),
        author: commenter,
        hidden: muted?,
        attachments: attachments,
      }
      group, students = group_students(user)
      comment[:group_comment_id] = CanvasSlug.generate_securish_uuid if group
      find_or_create_submissions(students).map do |submission|
        submission.add_comment(comment)
      end
    end
    [comments.compact, @ignored_files]
  end

  def group_category_name
    self.read_attribute(:group_category)
  end

  def maintain_group_category_attribute
    # keep this field up to date even though it's not used (group_category_name
    # exists solely for the migration that introduces the GroupCategory model).
    # this way group_category_name is correct if someone mistakenly uses it
    # (modulo category renaming in the GroupCategory model).
    self.write_attribute(:group_category, self.group_category && self.group_category.name)
  end

  def has_group_category?
    self.group_category_id.present?
  end

  def assign_peer_review(reviewer, reviewee)
    reviewer_submission = self.find_or_create_submission(reviewer)
    reviewee_submission = self.find_or_create_submission(reviewee)
    reviewee_submission.assign_assessor(reviewer_submission)
  end

  def assign_peer_reviews
    return [] unless self.peer_review_count && self.peer_review_count > 0

    # there could be any conceivable configuration of peer reviews already
    # assigned when this method is called, since teachers can assign individual
    # reviews manually and change peer_review_count at any time. so we can't
    # make many assumptions. that's where most of the complexity here comes
    # from.
    peer_review_params = current_submissions_and_assessors
    res = []

    # for each submission that needs to do more assessments...
    # we sort the submissions randomly so that if there aren't enough
    # submissions still needing reviews, it's random who gets the duplicate
    # reviews.
    peer_review_params[:submissions].sort_by { rand }.each do |submission|
      existing = submission.assigned_assessments
      needed = self.peer_review_count - existing.size
      next if needed <= 0

      # candidate_set is all submissions for the assignment that this
      # submission isn't already assigned to review.
      candidate_set = current_candidate_set(peer_review_params, submission, existing)
      candidates = sorted_review_candidates(peer_review_params, submission, candidate_set)

      # pick the number needed
      assessees = candidates[0, needed]

      # if there aren't enough candidates, we'll just not assign as many as
      # peer_review_count would allow. this'll only happen if peer_review_count
      # >= the number of submissions.
      assessees.each do |to_assess|
        # make the assignment
        res << to_assess.assign_assessor(submission)
        peer_review_params[:assessor_id_map][to_assess.id] << submission.id
      end
    end

    reviews_due_at = self.peer_reviews_assign_at || self.due_at
    if reviews_due_at && reviews_due_at < Time.zone.now
      self.peer_reviews_assigned = true
    end
    self.save
    res
  end

  def current_submissions_and_assessors
    # we track existing assessment requests, and the ones we create here, so
    # that we don't have to constantly re-query the db.
    student_ids = students_with_visibility(context.students.not_fake_student).pluck(:id)
    submissions = self.submissions.having_submission.include_assessment_requests.for_user(student_ids)
    { student_ids: student_ids,
      submissions: submissions,
      submission_ids: Set.new(submissions.pluck(:id)),
      assessor_id_map: Hash[submissions.map{|s| [s.id, s.assessment_requests.map(&:assessor_asset_id)] }] }
  end

  def sorted_review_candidates(peer_review_params, current_submission, candidate_set)
    assessor_id_map = peer_review_params[:assessor_id_map]
    candidates_for_review = peer_review_params[:submissions].select do |c|
      candidate_set.include?(c.id)
    end
    candidates_for_review.sort_by do |c|
      [
        # prefer those who need reviews done
        assessor_id_map[c.id].count < self.peer_review_count ? CanvasSort::First : CanvasSort::Last,
        # then prefer those who are not reviewing this submission
        assessor_id_map[current_submission.id].include?(c.id) ? CanvasSort::Last : CanvasSort::First,
        # then prefer those who need the most reviews done (that way we don't run the risk of
        # getting stuck with a submission needing more reviews than there are available reviewers left)
        assessor_id_map[c.id].count,
        # then prefer those who are assigned fewer reviews at this point --
        # this helps avoid loops where everybody is reviewing those who are
        # reviewing them, leaving the final assignee out in the cold.
        c.assigned_assessments.size,
        # random sort, all else being equal.
        rand,
      ]
    end
  end

  def current_candidate_set(peer_review_params, current_submission, existing)
    candidate_set = peer_review_params[:submission_ids] - existing.map(&:asset_id)
    if self.group_category_id && !self.intra_group_peer_reviews
      # don't assign to our group partners
      group_ids = peer_review_params[:submissions].select{|s| candidate_set.include?(s.id) && current_submission.group_id == s.group_id}.map(&:id)
      candidate_set -= group_ids
    else
      # don't assign to ourselves
      candidate_set.delete(current_submission.id) # don't assign to ourselves
    end
    candidate_set
  end

  # TODO: on a future deploy, rename the column peer_reviews_due_at
  # to peer_reviews_assign_at
  def peer_reviews_assign_at
    peer_reviews_due_at
  end

  def peer_reviews_assign_at=(val)
    write_attribute(:peer_reviews_due_at, val)
  end

  def has_peer_reviews?
    self.peer_reviews
  end

  def self.percent_considered_graded
    0.5
  end

  scope :include_submitted_count, -> { select(
    "assignments.*, (SELECT COUNT(*) FROM #{Submission.quoted_table_name}
    WHERE assignments.id = submissions.assignment_id
    AND submissions.submission_type IS NOT NULL
    AND submissions.workflow_state <> 'deleted') AS submitted_count") }

  scope :include_graded_count, -> { select(
    "assignments.*, (SELECT COUNT(*) FROM #{Submission.quoted_table_name}
    WHERE assignments.id = submissions.assignment_id
    AND submissions.grade IS NOT NULL
    AND submissions.workflow_state <> 'deleted') AS graded_count") }

  scope :include_submittables, -> { preload(:quiz, :discussion_topic, :wiki_page) }

  scope :submittable, -> { where.not(submission_types: [nil, *OFFLINE_SUBMISSION_TYPES]) }
  scope :no_submittables, -> { where.not(submission_types: SUBMITTABLE_TYPES) }

  scope :with_submissions, -> { preload(:submissions) }

  scope :with_submissions_for_user, lambda { |user|
    eager_load(:submissions).where(submissions: {user_id: user})
  }

  scope :starting_with_title, lambda { |title|
    where('title ILIKE ?', "#{title}%")
  }

  scope :having_submissions_for_user, lambda { |user|
    with_submissions_for_user(user).merge(Submission.having_submission)
  }

  scope :by_assignment_group_id, lambda { |group_id|
    where('assignment_group_id = ?', group_id.to_s)
  }

  scope :for_context_codes, lambda { |codes| where(:context_code => codes) }
  scope :for_course, lambda { |course_id| where(:context_type => 'Course', :context_id => course_id) }
  scope :for_group_category, lambda { |group_category_id| where(:group_category_id => group_category_id) }

  # NOTE: only use for courses with differentiated assignments on
  scope :visible_to_students_in_course_with_da, lambda { |user_id, course_id|
    joins(:assignment_student_visibilities).
    where(:assignment_student_visibilities => { :user_id => user_id, :course_id => course_id })
  }

  # course_ids should be courses that restrict visibility based on overrides
  # ie: courses with differentiated assignments on or in which the user is not a teacher
  scope :filter_by_visibilities_in_given_courses, lambda { |user_ids, course_ids_that_have_da_enabled|
    if course_ids_that_have_da_enabled.nil? || course_ids_that_have_da_enabled.empty?
      active
    else
      user_ids = Array.wrap(user_ids).join(',')
      course_ids = Array.wrap(course_ids_that_have_da_enabled).join(',')
      scope = joins(sanitize_sql([<<-SQL, course_ids, user_ids]))
        LEFT OUTER JOIN #{AssignmentStudentVisibility.quoted_table_name} ON (
         assignment_student_visibilities.assignment_id = assignments.id
         AND assignment_student_visibilities.course_id IN (%s)
         AND assignment_student_visibilities.user_id IN (%s))
      SQL
      scope.where("(assignments.context_id NOT IN (?) AND assignments.workflow_state<>'deleted') OR (assignment_student_visibilities.assignment_id IS NOT NULL)", course_ids_that_have_da_enabled)
    end
  }

  scope :due_before, lambda { |date| where("assignments.due_at<?", date) }

  scope :due_after, lambda { |date| where("assignments.due_at>?", date) }
  scope :undated, -> { where(:due_at => nil) }

  scope :with_just_calendar_attributes, -> {
    select(((Assignment.column_names & CalendarEvent.column_names) + ['due_at', 'assignment_group_id', 'could_be_locked', 'unlock_at', 'lock_at', 'submission_types', '(freeze_on_copy AND copied) AS frozen'] - ['cloned_item_id', 'migration_id']).join(", "))
  }

  scope :due_between, lambda { |start, ending| where(:due_at => start..ending) }

  # Return all assignments and their active overrides where either the
  # assignment or one of its overrides is due between start and ending.
  scope :due_between_with_overrides, lambda { |start, ending|
    joins("LEFT OUTER JOIN #{AssignmentOverride.quoted_table_name} assignment_overrides
          ON assignment_overrides.assignment_id = assignments.id").
    group("assignments.id").
    where('assignments.due_at BETWEEN ? AND ?
          OR assignment_overrides.due_at_overridden AND
          assignment_overrides.due_at BETWEEN ? AND ?', start, ending, start, ending)
  }

  scope :updated_after, lambda { |*args|
    if args.first
      where("assignments.updated_at IS NULL OR assignments.updated_at>?", args.first)
    else
      all
    end
  }

  scope :not_ignored_by, lambda { |user, purpose|
    where("NOT EXISTS (?)",
          Ignore.where(asset_type: 'Assignment',
                       user_id: user,
                       purpose: purpose).where('asset_id=assignments.id'))
  }

  # the map on the API_NEEDED_FIELDS here is because PostgreSQL will see the
  # query as ambigious for the "due_at" field if combined with another table
  # (e.g. assignment overrides) with similar fields (like id,lock_at,etc),
  # throwing an error.
  scope :api_needed_fields, -> { select(API_NEEDED_FIELDS.map{ |f| "assignments." + f.to_s}) }

  # This should only be used in the course drop down to show assignments needing a submission
  scope :need_submitting_info, lambda { |user_id, limit|
    chain = api_needed_fields.
      where("(SELECT COUNT(id) FROM #{Submission.quoted_table_name}
            WHERE assignment_id = assignments.id
            AND submissions.workflow_state <> 'deleted'
            AND (submission_type IS NOT NULL OR excused = ?)
            AND user_id = ?) = 0", true, user_id).
      limit(limit).
      order("assignments.due_at")

    # select doesn't work with include() in rails3, and include(:context)
    # doesn't work because of the polymorphic association. So we'll preload
    # context for the assignments in a single query.
    chain.preload(:context)
  }

  # This should only be used in the course drop down to show assignments not yet graded.
  scope :need_grading_info, lambda {
    chain = api_needed_fields.
      where("EXISTS (?)",
        Submission.active.where("assignment_id=assignments.id").
          where(Submission.needs_grading_conditions)).
      order("assignments.due_at")

    chain.preload(:context)
  }

  scope :expecting_submission, -> do
    where.not(submission_types: [nil, ''] + %w(none not_graded on_paper wiki_page))
  end

  scope :gradeable, -> { where.not(submission_types: %w(not_graded wiki_page)) }

  scope :active, -> { where("assignments.workflow_state<>'deleted'") }
  scope :before, lambda { |date| where("assignments.created_at<?", date) }

  scope :not_locked, -> {
    where("(assignments.unlock_at IS NULL OR assignments.unlock_at<:now) AND (assignments.lock_at IS NULL OR assignments.lock_at>:now)",
      :now => Time.zone.now)
  }

  scope :order_by_base_due_at, -> { order("assignments.due_at") }

  scope :unpublished, -> { where(:workflow_state => 'unpublished') }
  scope :published, -> { where(:workflow_state => 'published') }
  scope :api_id, lambda { |api_id|
    if api_id.start_with?('lti_context_id')
      lti_context_id = api_id.split(':').last
      find_by lti_context_id: lti_context_id
    else
      find api_id
    end
  }

  def overdue?
    due_at && due_at <= Time.zone.now
  end

  def readable_submission_types
    return nil unless expects_submission? || expects_external_submission?
    res = (self.submission_types || "").split(",").map{|s| readable_submission_type(s) }.compact
    res.to_sentence(:or)
  end

  def readable_submission_type(submission_type)
    case submission_type
    when 'online_quiz'
      t 'submission_types.a_quiz', "a quiz"
    when 'online_upload'
      t 'submission_types.a_file_upload', "a file upload"
    when 'online_text_entry'
      t 'submission_types.a_text_entry_box', "a text entry box"
    when 'online_url'
      t 'submission_types.a_website_url', "a website url"
    when 'discussion_topic'
      t 'submission_types.a_discussion_post', "a discussion post"
    when 'wiki_page'
      t 'submission_types.a_content_page', "a content page"
    when 'media_recording'
      t 'submission_types.a_media_recording', "a media recording"
    when 'on_paper'
      t 'submission_types.on_paper', "on paper"
    when 'external_tool'
      t 'submission_types.external_tool', "an external tool"
    else
      nil
    end
  end
  protected :readable_submission_type

  def expects_submission?
    submission_types.present? &&
      !expects_external_submission? &&
      !%w(none not_graded wiki_page).include?(submission_types)
  end

  def expects_external_submission?
    %w(on_paper external_tool).include?(submission_types)
  end

  def non_digital_submission?
    ["on_paper","none","not_graded",""].include?(submission_types.strip)
  end

  def allow_google_docs_submission?
    self.submission_types &&
      self.submission_types.match(/online_upload/)
  end

  def <=>(comparable)
    sort_key <=> comparable.sort_key
  end

  def sort_key
    # undated assignments go last
    [due_at || CanvasSort::Last, Canvas::ICU.collation_key(title)]
  end

  def special_class; nil; end

  def submission_action_string
    if submission_types == "online_quiz"
      t :submission_action_take_quiz, "Take %{title}", :title => title
    elsif graded? && expects_submission?
      t :submission_action_turn_in_assignment, "Turn in %{title}", :title => title
    else
      t "Complete %{title}", :title => title
    end
  end

  # Infers the user, submission, and attachment from a filename
  def infer_comment_context_from_filename(fullpath)
    filename = File.basename(fullpath)
    split_filename = filename.split('_')
    # If the filename is like Richards_David_2_link.html, then there is no
    # useful attachment here.  The assignment was submitted as a URL and the
    # teacher commented directly with the gradebook.  Otherwise, grab that
    # last value and strip off everything after the first period.
    user_id, attachment_id = split_filename.grep(/^\d+$/).take(2)
    attachment_id = nil if split_filename.last =~ /^link/ || filename =~ /^\._/

    if user_id
      user = User.where(id: user_id).first
      submission = Submission.active.where(user_id: user_id, assignment_id: self).first
    end
    attachment = Attachment.where(id: attachment_id).first if attachment_id

    if !attachment || !submission ||
       !attachment.grants_right?(user, :read) ||
       !submission.attachments.where(:id => attachment_id).exists?
      @ignored_files << fullpath
      return nil
    end

    {
      :user => user,
      :submission => submission,
      :filename => fullpath,
      :display_name => attachment.display_name
    }
  end
  protected :infer_comment_context_from_filename

  FREEZABLE_ATTRIBUTES = %w{title description lock_at points_possible grading_type
                            submission_types assignment_group_id allowed_extensions
                            group_category_id notify_of_update peer_reviews workflow_state}
  def frozen?
    !!(self.freeze_on_copy && self.copied &&
       PluginSetting.settings_for_plugin(:assignment_freezer))
  end

  # indicates complete frozenness for an assignment.
  # if the user can edit at least one of the attributes, it is not frozen to
  # them
  def frozen_for_user?(user)
    return true if user.blank?
    frozen? && !self.context.grants_right?(user, :manage_frozen_assignments)
  end

  def frozen_attributes_for_user(user)
    FREEZABLE_ATTRIBUTES.select do |freezable_attribute|
      att_frozen? freezable_attribute, user
    end
  end

  def att_frozen?(att, user=nil)
    return false unless frozen?
    if settings = PluginSetting.settings_for_plugin(:assignment_freezer)
      if Canvas::Plugin.value_to_boolean(settings[att.to_s])
        if user
          return !self.context.grants_right?(user, :manage_frozen_assignments)
        else
          return true
        end
      end
    end

    false
  end

  def can_copy?(user)
    !att_frozen?("no_copying", user)
  end

  def frozen_atts_not_altered
    return if self.copying
    FREEZABLE_ATTRIBUTES.each do |att|
      if self.changes[att] && att_frozen?(att, @updating_user)
        self.errors.add(att,
          t('errors.cannot_save_att',
            "You don't have permission to edit the locked attribute %{att_name}",
            :att_name => att))
      end
    end
  end

  def update_cached_due_dates
    return unless update_cached_due_dates?

    DueDateCacher.recompute(self)
  end

  def update_cached_due_dates?
    due_at_changed? || workflow_state_changed? || only_visible_to_overrides_changed?
  end

  def apply_late_policy
    return if update_cached_due_dates? # DueDateCacher already re-applies late policy so we shouldn't
    return unless grading_type_changed?

    LatePolicyApplicator.for_assignment(self)
  end

  def gradeable?
    submission_types != 'not_graded' && submission_types != 'wiki_page'
  end
  alias graded? gradeable?

  def gradeable_was?
    submission_types_was != 'not_graded' && submission_types_was != 'wiki_page'
  end

  def active?
    workflow_state != 'deleted'
  end

  def available?
    if Rails.env.production?
      published?
    else
      raise "Assignment#available? is deprecated. Use #published?"
    end
  end

  def has_student_submissions?
    if !@has_student_submissions.nil?
      @has_student_submissions
    elsif attribute_present? :student_submission_count
      student_submission_count.to_i > 0
    else
      submissions.having_submission.where("user_id IS NOT NULL").exists?
    end
  end
  attr_writer :has_student_submissions

  def group_category_deleted_with_submissions?
    self.group_category.try(:deleted_at?) && self.has_student_submissions?
  end

  def self.with_student_submission_count
    # need to make sure that Submission's table name is relative to the shard
    # this query will execute on
    all.primary_shard.activate do
      joins("LEFT OUTER JOIN #{Submission.quoted_table_name} s ON
             s.assignment_id = assignments.id AND
             s.submission_type IS NOT NULL AND
             s.workflow_state <> 'deleted'")
      .group("assignments.id")
      .select("assignments.*, count(s.assignment_id) AS student_submission_count")
    end
  end

  def needs_grading_count
    Assignments::NeedsGradingCountQuery.new(self).manual_count
  end

  def can_unpublish?
    return true if new_record?
    return @can_unpublish unless @can_unpublish.nil?
    @can_unpublish = !has_student_submissions?
  end
  attr_writer :can_unpublish

  def self.preload_can_unpublish(assignments, assmnt_ids_with_subs=nil)
    return unless assignments.any?
    assmnt_ids_with_subs ||= assignment_ids_with_submissions(assignments.map(&:id))
    assignments.each{|a| a.can_unpublish = !(assmnt_ids_with_subs.include?(a.id)) }
  end

  def self.assignment_ids_with_submissions(assignment_ids)
    Submission.active.having_submission.where(:assignment_id => assignment_ids).distinct.pluck(:assignment_id)
  end

  # override so validations are called
  def publish
    self.workflow_state = 'published'
    self.save
  end

  # override so validations are called
  def unpublish
    self.workflow_state = 'unpublished'
    self.save
  end

  def excused_for?(user)
    s = submissions.where(user_id: user.id).first_or_initialize
    s.excused?
  end

  def in_closed_grading_period?
    return @in_closed_grading_period unless @in_closed_grading_period.nil?
    @in_closed_grading_period = if submissions.loaded?
      submissions.map(&:grading_period).compact.any?(&:closed?)
    else
      GradingPeriod.joins(:submissions).where(submissions: {assignment_id: self.id}).closed.exists?
    end
  end

  # simply versioned models are always marked new_record, but for our purposes
  # they are not new. this ensures that assignment override caching works as
  # intended for versioned assignments
  def cache_key
    new_record = @new_record
    @new_record = false if @simply_versioned_version_model
    super
  ensure
    @new_record = new_record if @simply_versioned_version_model
  end

  def quiz?
    submission_types == 'online_quiz' && quiz.present?
  end

  def quiz_lti?
    external_tool? &&
      external_tool_tag.present? &&
      external_tool_tag.content.present? &&
      external_tool_tag.content.try(:tool_id) == 'Quizzes 2'
  end

  def quiz_lti!
    tool = context.present? && context.quiz_lti_tool
    return unless tool
    self.submission_types = 'external_tool'
    self.external_tool_tag_attributes = { content: tool, url: tool.url }
  end

  def discussion_topic?
    submission_types == 'discussion_topic' && discussion_topic.present?
  end

  def wiki_page?
    submission_types == 'wiki_page' && wiki_page.present?
  end

  def self.sis_grade_export_enabled?(context)
    context.feature_enabled?(:post_grades) ||
      context.root_account.feature_enabled?(:bulk_sis_grade_export) ||
      Lti::AppLaunchCollator.any?(context, [:post_grades])
  end

  def run_if_overrides_changed!(student_ids=nil)
    relocked_modules = []
    self.relock_modules!(relocked_modules, student_ids)
    each_submission_type { |submission| submission.relock_modules!(relocked_modules, student_ids) if submission }

    if only_visible_to_overrides?
      Rails.logger.info "GRADES: recalculating because assignment overrides on #{global_id} changed."
      context.recompute_student_scores
    end
  end

  def run_if_overrides_changed_later!(student_ids=nil)
    if student_ids
      self.send_later_if_production_enqueue_args(:run_if_overrides_changed!, {:strand => "assignment_overrides_changed_for_students_#{self.global_id}"}, student_ids)
    else
      self.send_later_if_production_enqueue_args(:run_if_overrides_changed!, {:singleton => "assignment_overrides_changed_#{self.global_id}"})
    end
  end

  def validate_overrides_for_sis(overrides)
    unless AssignmentUtil.sis_integration_settings_enabled?(context) && AssignmentUtil.due_date_required_for_account?(context)
      @skip_due_date_validation = true
      return
    end
    raise ActiveRecord::RecordInvalid unless assignment_overrides_due_date_ok?(overrides)
    @skip_due_date_validation = true
  end

  private

  def due_date_ok?
    unless AssignmentUtil.due_date_ok?(self)
      errors.add(:due_at, I18n.t("due_at", "cannot be blank when Post to Sis is checked"))
    end
  end

  def assignment_overrides_due_date_ok?(overrides={})
    if AssignmentUtil.due_date_required?(self)
      overrides = gather_override_data(overrides)
      if overrides.select{|o| o['due_at'].nil?}.length > 0
        errors.add(:due_at, I18n.t("cannot be blank for any assignees when Post to Sis is checked"))
        return false
      end
    end
    true
  end

  def gather_override_data(overrides)
    return self.assignment_overrides unless self.assignment_overrides.empty?
    return overrides.values.reject(&:empty?).flatten if overrides.is_a?(Hash)
    overrides
  end

  def active_assignment_overrides?
    @skip_due_date_validation || self.assignment_overrides.length > 0
  end

  def assignment_name_length_ok?
    name_length = max_name_length

    # Due to the removal of the multiple `validates_length_of :title` validations we need this nil check
    # here to act as those validations so we can reduce the number of validations for this attribute
    # to just one single check
    return if self.nil? || self.title.nil?

    if self.title.to_s.length > name_length && self.grading_type != 'not_graded'
      errors.add(:title, I18n.t('The title cannot be longer than %{length} characters', length: name_length))
    end
  end
end
