#
# Copyright (C) 2013 - present Instructure, Inc.
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

class Feature
  ATTRS = [:feature, :display_name, :description, :applies_to, :state,
           :root_opt_in, :enable_at, :beta, :development,
           :release_notes_url, :custom_transition_proc,
           :after_state_change_proc, :autoexpand, :touch_context,
           :use_settings_service].freeze

  attr_reader *ATTRS

  def initialize(opts = {})
    @state = 'allowed'
    opts.each do |key, val|
      next unless ATTRS.include?(key)
      val = (Feature.production_environment? ? 'hidden' : 'allowed') if key == :state && val == 'hidden_in_prod'
      next if key == :state && !%w(hidden off allowed on).include?(val)
      instance_variable_set "@#{key}", val
    end
    # for RootAccount features, "allowed" state is redundant; show "off" instead
    @root_opt_in = true if @applies_to == 'RootAccount'
  end

  def clone_for_cache
    Feature.new(feature: @feature, state: @state)
  end

  def default?
    true
  end

  def locked?(query_context)
    query_context.blank? || !allowed? && !hidden?
  end

  def enabled?
    @state == 'on'
  end

  def allowed?
    @state == 'allowed'
  end

  def hidden?
    @state == 'hidden'
  end

  def self.production_environment?
    Rails.env.production? && !(ApplicationController.respond_to?(:test_cluster?) && ApplicationController.test_cluster?)
  end

  # Register one or more features.  Must be done during application initialization.
  # The feature_hash is as follows:
  #   automatic_essay_grading: {
  #     display_name: -> { I18n.t('features.automatic_essay_grading', 'Automatic Essay Grading') },
  #     description: -> { I18n.t('features.automatic_essay_grading_description, 'Popup text describing the feature goes here') },
  #     applies_to: 'Course', # or 'RootAccount' or 'Account' or 'User'
  #     state: 'allowed',     # or 'off', 'on', 'hidden', or 'hidden_in_prod'
  #                           # - 'hidden' means the feature must be set by a site admin before it will be visible
  #                           #   (in that context and below) to other users
  #                           # - 'hidden_in_prod' registers 'hidden' in production environments or 'allowed' elsewhere
  #     root_opt_in: false,   # if true, 'allowed' features in source or site admin
  #                           # will be inherited in "off" state by root accounts
  #     enable_at: Date.new(2014, 1, 1),  # estimated release date shown in UI
  #     beta: false,          # 'beta' tag shown in UI
  #     development: false,   # whether the feature is restricted to development / test / beta instances
  #                           # setting `development: true` prevents the flag from being registered on production,
  #                           # which means `context.feature_enabled?` calls for the feature will always return false.
  #     release_notes_url: 'http://example.com/',
  #
  #     # optional: you can supply a Proc to attach warning messages to and/or forbid certain transitions
  #     # see lib/feature/draft_state.rb for example usage
  #     custom_transition_proc: ->(user, context, from_state, transitions) do
  #       if from_state == 'off' && context.is_a?(Course) && context.has_submitted_essays?
  #         transitions['on']['warning'] = I18n.t('features.automatic_essay_grading.enable_warning',
  #           'Enabling this feature after some students have submitted essays may yield inconsistent grades.')
  #       end
  #     end,
  #
  #     # optional hook to be called before after a feature flag change
  #     # queue a delayed_job to perform any nontrivial processing
  #     after_state_change_proc:  ->(user, context, old_state, new_state) { ... }
  #   }

  def self.register(feature_hash)
    @features ||= {}
    feature_hash.each do |feature_name, attrs|
      next if attrs[:development] && production_environment?
      feature = feature_name.to_s
      @features[feature] = Feature.new({feature: feature}.merge(attrs))
    end
  end

  # TODO: register built-in features here
  # (plugins may register additional features during application initialization)
  register(
    'google_docs_domain_restriction' =>
    {
      display_name: -> { I18n.t('features.google_docs_domain_restriction', 'Google Docs Domain Restriction') },
      description: -> { I18n.t('google_docs_domain_restriction_description', <<END) },
Google Docs Domain Restriction allows Google Docs submissions and collaborations
to be restricted to a single domain. Students attempting to submit assignments or
join collaborations on an unapproved domain will receive an error message notifying them
that they will need to update their Google Docs integration.
END
      applies_to: 'RootAccount',
      state: 'hidden',
      root_opt_in: true
    },
    'epub_export' =>
    {
      display_name: -> { I18n.t('ePub Exporting') },
      description: -> { I18n.t(<<END) },
      This enables users to generate and download course ePub.
END
      applies_to: 'Course',
      state: 'allowed',
      root_opt_in: true,
      beta: true
    },
    'high_contrast' =>
    {
      display_name: -> { I18n.t('features.high_contrast', 'High Contrast UI') },
      description: -> { I18n.t('high_contrast_description', <<-END) },
High Contrast enhances the color contrast of the UI (text, buttons, etc.), making those items more
distinct and easier to identify. Note: Institution branding will be disabled.
END
      applies_to: 'User',
      state: 'allowed',
      autoexpand: true
    },
    'underline_all_links' =>
    {
      display_name: -> { I18n.t('Underline Links') },
      description: -> { I18n.t('underline_all_links_description', <<-END, wrapper: { '*' => '<span class="feature-detail-underline">\1</span>' })},
Underline Links displays hyperlinks in navigation menus, the Dashboard, and page sidebars as
*underlined text*. This feature option does not apply to user-generated content links in the
Rich Content Editor, which always underlines links for all users.
END
      applies_to: 'User',
      state: 'allowed',
      beta: true
    },
    'new_user_tutorial_on_off' =>
    {
      display_name: -> { I18n.t('Course Set-up Tutorial') },
      description: -> { I18n.t('Course set-up tutorial provides tips on how to leverage the feature opportunities on each page in Canvas. It is especially useful when you are new to Canvas or are setting up a new course for the first time in a long time.') },
      applies_to: 'User',
      state: 'allowed',
    },

    'outcome_gradebook' =>
    {
      display_name: -> { I18n.t('features.learning_mastery_gradebook', 'Learning Mastery Gradebook') },
      description:  -> { I18n.t('learning_mastery_gradebook_description', <<-END) },
Learning Mastery Gradebook provides a way for teachers to quickly view student and course
progress on course learning outcomes. Outcomes are presented in a Gradebook-like
format and student progress is displayed both as a numerical score and as mastered/near
mastery/remedial.
END
      applies_to: 'Course',
      state: 'allowed',
      root_opt_in: false
    },
    'student_outcome_gradebook' =>
    {
      display_name: -> { I18n.t('features.student_outcome_gradebook', 'Student Learning Mastery Gradebook') },
      description:  -> { I18n.t('student_outcome_gradebook_description', <<-END) },
Student Learning Mastery Gradebook provides a way for students to quickly view progress
on course learning outcomes. Outcomes are presented in a Gradebook-like
format and progress is displayed both as a numerical score and as mastered/near
mastery/remedial.
END
      applies_to: 'Course',
      state: 'allowed',
      root_opt_in: false
    },
    'post_grades' =>
    {
      display_name: -> { I18n.t('features.post_grades', 'Post Grades to SIS') },
      description:  -> { I18n.t('post_grades_description', <<-END) },
Post Grades allows teachers to post grades back to enabled SIS systems: Powerschool,
Aspire (SIS2000), JMC, and any other SIF-enabled SIS that accepts the SIF elements GradingCategory,
GradingAssignment, GradingAssignmentScore.
END
      applies_to: 'Course',
      state: 'hidden',
      root_opt_in: true,
      beta: true
    },
    'new_gradebook' =>
    {
      display_name: -> { I18n.t('New Gradebook') },
      description:  -> { I18n.t(<<-END) },
New Gradebook enables an early release of new Gradebook enhancements.
END
      applies_to: 'Course',
      state: 'hidden',
      root_opt_in: true,
      beta: true,

      custom_transition_proc: ->(user, context, _from_state, transitions) do
        if context.is_a?(Course)
          user_may_change_flag = context.account.grants_right?(user, :manage_account_settings)
          transitions['on']['locked'] = !user_may_change_flag if transitions&.dig('on')
          transitions['off']['locked'] = !user_may_change_flag if transitions&.dig('off')
        elsif context.is_a?(Account)
          transitions['on']['locked'] = true if transitions&.dig('on')
        end
      end
    },
    'k12' =>
    {
      display_name: -> { I18n.t('features.k12', 'K-12 Specific Features') },
      description:  -> { I18n.t('k12_description', <<-END) },
Features, settings and styles that make more sense specifically in a K-12 environment. For now, this only
applies some style changes, but more K-12 specific things may be added in the future.
END
      applies_to: 'RootAccount',
      state: 'hidden',
      root_opt_in: true,
      beta: true
    },
    'recurring_calendar_events' =>
    {
      display_name: -> { I18n.t('Recurring Calendar Events') },
      description: -> { I18n.t("Allows the scheduling of recurring calendar events") },
      applies_to: 'Course',
      state: 'allowed',
      root_opt_in: false,
      beta: false
    },
    'allow_opt_out_of_inbox' =>
    {
      display_name: -> { I18n.t('features.allow_opt_out_of_inbox', "Allow Users to Opt-out of the Inbox") },
      description:  -> { I18n.t('allow_opt_out_of_inbox', <<-END) },
Allow users to opt out of the Conversation's Inbox. This will cause all conversation messages and notifications to be sent as ASAP notifications to the user's primary email, hide the Conversation's Inbox unread messages badge on the Inbox, and hide the Conversation's notification preferences.
END
      applies_to: 'RootAccount',
      state: 'hidden',
      root_opt_in: true
    },
    'lor_for_user' =>
    {
      display_name: -> { I18n.t('features.lor', "LOR External Tools") },
      description:  -> { I18n.t('allow_lor_tools', <<-END) },
Allow users to view and use external tools configured for LOR.
END
      applies_to: 'User',
      state: 'hidden'
    },
    'lor_for_account' =>
    {
      display_name: -> { I18n.t('features.lor', "LOR External Tools") },
      description:  -> { I18n.t('allow_lor_tools', <<-END) },
Allow users to view and use external tools configured for LOR.
END
      applies_to: 'RootAccount',
      state: 'hidden'
    },
    'course_catalog' =>
    {
      display_name: -> { I18n.t("Public Course Index") },
      description:  -> { I18n.t('display_course_catalog', <<-END) },
Show a searchable list of courses in this root account with the "Include this course in the public course index" flag enabled.
END
      applies_to: 'RootAccount',
      state: 'allowed',
      beta: true,
      root_opt_in: true
    },
    'gradebook_list_students_by_sortable_name' =>
    {
      display_name: -> { I18n.t('features.gradebook_list_students_by_sortable_name', "Gradebook - List Students by Sortable Name") },
      description: -> { I18n.t('enable_gradebook_list_students_by_sortable_name', <<-END) },
List students by their sortable names in the Gradebook. Sortable name defaults to 'Last Name, First Name' and can be changed in settings.
END
      applies_to: 'Course',
      state: 'allowed'
    },
    'usage_rights_required' =>
    {
      display_name: -> { I18n.t('Require Usage Rights for Uploaded Files') },
      description: -> { I18n.t('If enabled, content designers must provide copyright and license information for files before they are published. Only applies if Better File Browsing is also enabled.') },
      applies_to: 'Course',
      state: 'hidden',
      root_opt_in: true
    },
    'lti2_rereg' =>
    {
      display_name: -> {I18n.t('LTI 2 Reregistration')},
      description: -> { I18n.t('Enable reregistration for LTI 2 ')},
      applies_to:'RootAccount',
      state: 'hidden',
      beta: true
    },
    'quizzes_lti' =>
    {
      display_name: -> { I18n.t('Quiz LTI Plugin') },
      description: -> { I18n.t('Use the new quiz LTI tool in place of regular canvas quizzes') },
      applies_to: 'Course',
      state: 'hidden',
      beta: true,
      root_opt_in: true
    },
    'disable_lti_post_only' =>
    {
      display_name: -> { I18n.t('Don\'t Move LTI Query Params to POST Body') },
      description: -> { I18n.t('If enabled, query parameters will not be copied to the POST body during an LTI launch.') },
      applies_to: 'RootAccount',
      state: 'hidden',
      beta: true,
      root_opt_in: true
    },
    'new_sis_integrations' =>
    {
      display_name: -> { I18n.t('Enable new SIS integration settings') },
      description:  -> { I18n.t('new_sis_integrations', <<-END) },
This feature applies to institutions with an existing SIS Canvas integration.
Any customers that are currently using grade passback solutions in Canvas or
partner products should enable this feature for enhanced assignment data
validation workflows. When enabled, this feature displays the new SIS
Integration settings for SIS Sync (Assignment Level Grade Passback) in Account
Settings. The Post to SIS feature option has been incorporated into this new
setting and will be enabled by default.
END
      applies_to: 'Account',
      state: 'hidden',
      root_opt_in: true,
      beta: true
    },
    'bulk_sis_grade_export' =>
      {
        display_name: -> { I18n.t('Allow Bulk Grade Export to SIS') },
        description:  -> { I18n.t('Allows teachers to mark grade data to be exported in bulk to SIS integrations.') },
        applies_to: 'RootAccount',
        state: 'hidden',
        root_opt_in: true,
        beta: true
      },
    'notification_service' =>
    {
      display_name: -> { I18n.t('Use remote service for notifications') },
      description: -> { I18n.t('Allow the ability to send notifications through our dispatch queue') },
      applies_to: 'RootAccount',
      state: 'hidden',
      beta: true,
      development: false,
      root_opt_in: false
    },
    'better_scheduler' =>
    {
      display_name: -> { I18n.t('Use the new scheduler') },
      description: -> { I18n.t('Uses the new scheduler and its functionality') },
      applies_to: 'RootAccount',
      state: 'hidden',
      beta: true,
      development: false,
      root_opt_in: false
    },
    'use_new_tree' =>
    {
      display_name: -> { I18n.t('Use New Folder Tree in Files')},
      description: -> {I18n.t('Replaces the current folder tree with a new accessible and more feature rich folder tree.')},
      applies_to: 'Course',
      state: 'hidden',
      development: true,
      root_opt_in: true
    },
    'course_card_images' =>
    {
      display_name: -> { I18n.t('Enable Dashboard Images for Courses')},
      description: -> {I18n.t('Allow course images to be assigned to a course and used on the dashboard cards.')},
      applies_to: 'Course',
      state: 'allowed',
      root_opt_in: true,
      beta: true
    },
    'dashcard_reordering' =>
    {
      display_name: -> { I18n.t('Allow Reorder Dashboard Cards') },
      description: -> { I18n.t('Allow dashboard cards to be reordered for each user.') },
      applies_to: 'RootAccount',
      state: 'hidden',
      beta: true,
      development: true,
      root_opt_in: false
    },
    'anonymous_grading' => {
      display_name: -> { I18n.t('Anonymous Grading') },
      description: -> { I18n.t("Anonymous grading forces student names to be hidden in SpeedGrader™") },
      applies_to: 'Course',
      state: 'allowed'
    },
    'international_sms' => {
      display_name: -> { I18n.t('International SMS') },
      description: -> { I18n.t('Allows users with international phone numbers to receive text messages from Canvas.') },
      applies_to: 'RootAccount',
      state: 'hidden',
      root_opt_in: true
    },
    'course_user_search' => {
      display_name: -> { I18n.t('Account Course and User Search') },
      description: -> { I18n.t('Updated UI for searching and displaying users and courses within an account.') },
      applies_to: 'Account',
      state: 'hidden',
      beta: true,
      development: true,
      root_opt_in: true,
      touch_context: true
    },
    'rich_content_service_high_risk' =>
    {
      display_name: -> { I18n.t('Rich Content Editor Sidebar Enhancements') },
      description: -> { I18n.t('Use new rich content editor with enhanced sidebar everywhere') },
      applies_to: 'RootAccount',
      state: 'hidden',
      beta: false,
      development: false,
      root_opt_in: false
    },
    'conditional_release' =>
    {
      display_name: -> { I18n.t('Mastery Paths') },
      description: -> { I18n.t('Configure individual learning paths for students based on assessment results.') },
      applies_to: 'Course',
      state: 'allowed',
      beta: true,
      development: false,
      root_opt_in: true,
      after_state_change_proc:  ->(user, context, _old_state, new_state) {
        if %w(on allowed).include?(new_state) && context.is_a?(Account)
          @service_account = ConditionalRelease::Setup.new(context.id, user.id)
          @service_account.activate!
        end
      }
    },
    'wrap_calendar_event_titles' =>
    {
      display_name: -> { I18n.t('Wrap event titles in Calendar month view') },
      description: -> { I18n.t("Show calendar events in the month view on multiple lines if the title doesn't fit on a single line") },
      applies_to: 'RootAccount',
      state: 'allowed',
      root_opt_in: true
    },
    'new_collaborations' =>
    {
      display_name: -> { I18n.t("External Collaborations Tool") },
      description: -> { I18n.t("Use the new Collaborations external tool enabling more options for tools to use to collaborate") },
      applies_to: 'Course',
      state: 'hidden',
      development: false,
      root_opt_in: true,
      touch_context: true
    },
    'new_annotations' =>
    {
      display_name: -> { I18n.t('New Annotations') },
      description: -> { I18n.t('Use the new document annotation tool') },
      applies_to: 'Account',
      state: 'hidden',
      beta: true,
      root_opt_in: true,
      custom_transition_proc: ->(_, _, from_state, transitions) do
        if from_state == 'on'
          transitions['off'] = { 'locked' => true, 'message' => I18n.t('This feature cannot be disabled once it has been turned on.') }
          transitions['allowed'] = { 'locked' => true, 'message' => I18n.t('This feature cannot be disabled once it has been turned on.') }
        end
      end
    },
    'plagiarism_detection_platform' =>
    {
      display_name: -> { I18n.t('Plagiarism Detection Platform') },
      description: -> { I18n.t('Enable the plagiarism detection platform') },
      applies_to: 'RootAccount',
      state: 'hidden',
      beta: true,
      root_opt_in: true
    },
    'master_courses' =>
    {
      display_name: -> { I18n.t('Blueprint Courses') }, # this won't be confusing at all
      description: -> { I18n.t('Enable the creation of Blueprint Courses') },
      applies_to: 'RootAccount',
      state: 'allowed',
      beta: true,
    },
    'student_context_cards' =>
    {
      display_name: -> { I18n.t('Student Context Card') },
      description: -> { I18n.t('Enable student context card links') },
      applies_to: "RootAccount",
      state: "allowed",
      beta: true
    },
    'new_gradebook_history' =>
    {
      display_name: -> { I18n.t('New Gradebook History') },
      description: -> { I18n.t('Enable New Gradebook History page.') },
      applies_to: "RootAccount",
      state: "hidden",
      beta: true,
      development: true,
    },
    'new_user_tutorial' =>
    {
      display_name: -> { I18n.t('New User Tutorial')},
      description: -> { I18n.t('Provide tutorial information for new users in a flyout tray.')},
      applies_to: "RootAccount",
      state: "allowed",
    },
    'student_planner' =>
    {
      display_name: -> { I18n.t('To Do List Dashboard')},
      description: -> { I18n.t('Provides users with a To Do List Dashboard option.')},
      applies_to: "RootAccount",
      state: "hidden",
      beta: true,
      development: false
    },
    'quizzes2_exporter' =>
    {
      display_name: -> { I18n.t('Export to Quizzes 2 format') },
      description: -> { I18n.t('Export an existing quiz to new Quizzes 2 format') },
      applies_to: "RootAccount",
      state: "hidden_in_prod",
      root_opt_in: true
    },
    'lti_2_auth_url_registration' =>
    {
      display_name: -> { I18n.t('Send Authorization URL in LTI2 Registration') },
      description: -> { I18n.t("If enabled, 'oauth2_access_token_url' will be sent in LTI2 registration launch") },
      applies_to: 'RootAccount',
      state: 'hidden',
      beta: false,
      root_opt_in: true
    },
    'graphql' =>
    {
      display_name: -> { I18n.t("GraphQL API") },
      description: -> { I18n.t("EXPERIMENTAL GraphQL API.") },
      applies_to: "RootAccount",
      state: "hidden",
      beta: true,
      development: true,
    },
    'hide_inbox' =>
    {
      display_name: -> { "Hide Inbox" },
      description: -> { "Hides the inbox." },
      applies_to: "RootAccount",
      state: "allowed",
      beta: false,
      development: false,
      use_settings_service: true
    },
    'zero_out_past_due' =>
    {
      display_name: -> { "Auto-grade past due assignments" },
      description: -> { "Automatically assign a grade of zero to past due assignments." },
      applies_to: "RootAccount",
      state: "allowed",
      beta: false,
      development: false,
      use_settings_service: true
    },
    'auto_due_dates' =>
    {
      display_name: -> { "Distribute due dates on import" },
      description: -> { "Distribute due dates evenly across the duration of the course" },
      applies_to: "RootAccount",
      state: "allowed",
      beta: false,
      development: false,
      use_settings_service: true
    }
  )

  def self.definitions
    @features ||= {}
    @features.freeze unless @features.frozen?
    @features
  end

  def applies_to_object(object)
    case @applies_to
    when 'RootAccount'
      object.is_a?(Account) && object.root_account?
    when 'Account'
      object.is_a?(Account)
    when 'Course'
      object.is_a?(Course) || object.is_a?(Account)
    when 'User'
      object.is_a?(User) || object.is_a?(Account) && object.site_admin?
    else
      false
    end
  end

  def self.feature_applies_to_object(feature, object)
    feature_def = definitions[feature.to_s]
    return false unless feature_def
    feature_def.applies_to_object(object)
  end

  def self.applicable_features(object)
    applicable_types = []
    if object.is_a?(Account)
      applicable_types << 'Account'
      applicable_types << 'Course'
      applicable_types << 'RootAccount' if object.root_account?
      applicable_types << 'User' if object.site_admin?
    elsif object.is_a?(Course)
      applicable_types << 'Course'
    elsif object.is_a?(User)
      applicable_types << 'User'
    end
    definitions.values.select{ |fd| applicable_types.include?(fd.applies_to) }
  end

  def default_transitions(context, orig_state)
    valid_states = %w(off on)
    valid_states << 'allowed' if context.is_a?(Account)
    (valid_states - [orig_state]).inject({}) do |transitions, state|
      transitions[state] = { 'locked' => (state == 'allowed' && @applies_to == 'RootAccount' &&
          context.is_a?(Account) && context.root_account? && !context.site_admin?) }
      transitions
    end
  end

  def transitions(user, context, orig_state)
    h = default_transitions(context, orig_state)
    if @custom_transition_proc.is_a?(Proc)
      @custom_transition_proc.call(user, context, orig_state, h)
    end
    h
  end

  def self.transitions(feature_name, user, context, orig_state)
    fd = definitions[feature_name.to_s]
    return nil unless fd
    fd.transitions(user, context, orig_state)
  end
end

# load feature definitions
Dir.glob("#{Rails.root}/lib/features/*.rb").each { |file| require_dependency file }
