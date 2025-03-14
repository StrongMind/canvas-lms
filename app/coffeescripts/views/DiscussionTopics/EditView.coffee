#
# Copyright (C) 2012 - present Instructure, Inc.
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

define [
  'i18n!discussion_topics'
  'compiled/views/ValidatedFormView'
  'compiled/views/assignments/AssignmentGroupSelector'
  'compiled/views/assignments/GradingTypeSelector'
  'compiled/views/assignments/GroupCategorySelector'
  'compiled/views/assignments/PeerReviewsSelector'
  'compiled/views/assignments/PostToSisSelector'
  'underscore'
  'jst/DiscussionTopics/EditView'
  'jsx/shared/rce/RichContentEditor'
  'str/htmlEscape'
  'compiled/models/DiscussionTopic'
  'compiled/models/Announcement'
  'compiled/models/Assignment'
  'jquery'
  'compiled/fn/preventDefault'
  'compiled/views/calendar/MissingDateDialogView'
  'compiled/views/editor/KeyboardShortcuts'
  'jsx/shared/conditional_release/ConditionalRelease'
  'compiled/util/deparam'
  'compiled/jquery.rails_flash_notifications' #flashMessage
  'jsx/shared/helpers/numberHelper'
  'compiled/util/SisValidationHelper'
], (
    I18n,
    ValidatedFormView,
    AssignmentGroupSelector,
    GradingTypeSelector,
    GroupCategorySelector,
    PeerReviewsSelector,
    PostToSisSelector,
    _,
    template,
    RichContentEditor,
    htmlEscape,
    DiscussionTopic,
    Announcement,
    Assignment,
    $,
    preventDefault,
    MissingDateDialog,
    KeyboardShortcuts,
    ConditionalRelease,
    deparam,
    flashMessage,
    numberHelper,
    SisValidationHelper) ->

  RichContentEditor.preloadRemoteModule()

  class EditView extends ValidatedFormView

    template: template

    tagName: 'form'

    className: 'form-horizontal no-margin'

    dontRenableAfterSaveSuccess: true

    els:
      '#availability_options': '$availabilityOptions'
      '#use_for_grading': '$useForGrading'
      '#discussion_topic_assignment_points_possible' : '$assignmentPointsPossible'
      '#discussion_point_change_warning' : '$discussionPointPossibleWarning'
      '#discussion-edit-view' : '$discussionEditView'
      '#discussion-details-tab' : '$discussionDetailsTab'
      '#conditional-release-target' : '$conditionalReleaseTarget'
      '#todo_options': '$todoOptions'
      '#todo_date_input': '$todoDateInput'
      '#allow_todo_date': '$allowTodoDate'

    events: _.extend(@::events,
      'click .removeAttachment' : 'removeAttachment'
      'click .save_and_publish': 'saveAndPublish'
      'click .cancel_button' : 'handleCancel'
      'change #use_for_grading' : 'toggleGradingDependentOptions'
      'change #discussion_topic_assignment_points_possible' : 'handlePointsChange'
      'change' : 'onChange'
      'tabsbeforeactivate #discussion-edit-view' : 'onTabChange'
      'change #allow_todo_date' : 'toggleTodoDateInput'
    )

    messages:
      group_category_section_label: I18n.t('group_discussion_title', 'Group Discussion')
      group_category_field_label: I18n.t('this_is_a_group_discussion', 'This is a Group Discussion')
      group_locked_message: I18n.t('group_discussion_locked', 'Students have already submitted to this discussion, so group settings cannot be changed.')

    @optionProperty 'permissions'

    initialize: (options) ->
      @assignment = @model.get("assignment")
      @initialPointsPossible = @assignment.pointsPossible()
      @dueDateOverrideView = options.views['js-assignment-overrides']
      @excludeStudentsView = options.views['js-exclude-students']
      @unassignStudentsView = options.views['js-unassign-students']

      @on 'success', =>
        @unwatchUnload()
        @redirectAfterSave()
      super

      @lockedItems = options.lockedItems || {}

    redirectAfterSave: ->
      window.location = @locationAfterSave(deparam())

    locationAfterSave: (params) =>
      if params['return_to']
        params['return_to']
      else
        @model.get 'html_url'

    redirectAfterCancel: ->
      location = @locationAfterCancel(deparam())
      window.location = location if location

    locationAfterCancel: (params) =>
      return params['return_to'] if params['return_to']?
      return ENV.CANCEL_TO if ENV.CANCEL_TO?
      null

    isTopic: => @model.constructor is DiscussionTopic

    isAnnouncement: => @model.constructor is Announcement

    canPublish: =>
      !@isAnnouncement() && !@model.get('published') && @permissions.CAN_MODERATE

    toJSON: ->
      data = super
      json = _.extend data, @options,
        showAssignment: !!@assignmentGroupCollection
        useForGrading: @model.get('assignment')?
        isTopic: @isTopic()
        isAnnouncement: @isAnnouncement()
        canPublish: @canPublish()
        contextIsCourse: @options.contextType is 'courses'
        canAttach: @permissions.CAN_ATTACH
        canModerate: @permissions.CAN_MODERATE
        isLargeRoster: ENV?.IS_LARGE_ROSTER || false
        threaded: data.discussion_type is "threaded"
        inClosedGradingPeriod: @assignment.inClosedGradingPeriod()
        lockedItems: @lockedItems
        allow_todo_date: data.todo_date?
      json.assignment = json.assignment.toView()
      json


    handleCancel: (ev) =>
      ev.preventDefault()
      @unwatchUnload()
      @redirectAfterCancel()

    handlePointsChange:(ev) =>
      ev.preventDefault()
      @assignment.pointsPossible(@$assignmentPointsPossible.val())
      if @assignment.hasSubmittedSubmissions()
        @$discussionPointPossibleWarning.toggleAccessibly(@assignment.pointsPossible() != @initialPointsPossible)


    # also separated for easy stubbing
    loadNewEditor: ($textarea)->
      return if @lockedItems.content
      RichContentEditor.loadNewEditor($textarea, { focus: true, manageParent: true})

    render: =>
      super
      $textarea = @$('textarea[name=message]').attr('id', _.uniqueId('discussion-topic-message'))

      unless @lockedItems.content
        RichContentEditor.initSidebar()
        _.defer =>
          @loadNewEditor($textarea)
          $('.rte_switch_views_link').click (event) ->
            event.preventDefault()
            event.stopPropagation()
            RichContentEditor.callOnRCE($textarea, 'toggle')
            # hide the clicked link, and show the other toggle link.
            # todo: replace .andSelf with .addBack when JQuery is upgraded.
            $(event.currentTarget).siblings('.rte_switch_views_link').andSelf().toggle()
      if @assignmentGroupCollection
        (@assignmentGroupFetchDfd ||= @assignmentGroupCollection.fetch()).done @renderAssignmentGroupOptions

      _.defer(@renderGradingTypeOptions)
      _.defer(@renderGroupCategoryOptions)
      _.defer(@renderPeerReviewOptions)
      _.defer(@renderPostToSisOptions) if ENV.POST_TO_SIS
      _.defer(@watchUnload)
      _.defer(@attachKeyboardShortcuts)
      _.defer(@renderTabs) if @showConditionalRelease()
      _.defer(@loadConditionalRelease) if @showConditionalRelease()

      @$(".datetime_field").datetime_field()

      this

    attachKeyboardShortcuts: =>
        $('.rte_switch_views_link').first().before((new KeyboardShortcuts()).render().$el)

    renderAssignmentGroupOptions: =>
      @assignmentGroupSelector = new AssignmentGroupSelector
        el: '#assignment_group_options'
        assignmentGroups: @assignmentGroupCollection.toJSON()
        parentModel: @assignment
        nested: true

      @assignmentGroupSelector.render()

    renderGradingTypeOptions: =>
      @gradingTypeSelector = new GradingTypeSelector
        el: '#grading_type_options'
        parentModel: @assignment
        nested: true
        preventNotGraded: true

      @gradingTypeSelector.render()

    renderGroupCategoryOptions: =>
      @groupCategorySelector = new GroupCategorySelector
        el: '#group_category_options'
        parentModel: @model
        groupCategories: ENV.GROUP_CATEGORIES
        hideGradeIndividually: true
        sectionLabel: @messages.group_category_section_label
        fieldLabel: @messages.group_category_field_label
        lockedMessage: @messages.group_locked_message
        inClosedGradingPeriod: @assignment.inClosedGradingPeriod()

      @groupCategorySelector.render()

    renderPeerReviewOptions: =>
      @peerReviewSelector = new PeerReviewsSelector
        el: '#peer_review_options'
        parentModel: @assignment
        nested: true
        hideAnonymousPeerReview: true

      @peerReviewSelector.render()

    renderPostToSisOptions: =>
      @postToSisSelector = new PostToSisSelector
        el: '#post_to_sis_options'
        parentModel: @assignment
        nested: true

      @postToSisSelector.render()

    renderTabs: =>
      @$discussionEditView.tabs()
      @toggleConditionalReleaseTab()

    loadConditionalRelease: =>
      if !ENV.CONDITIONAL_RELEASE_ENV
        return # can happen during unit tests due to _.defer
      @conditionalReleaseEditor = ConditionalRelease.attach(
        @$conditionalReleaseTarget.get(0),
        I18n.t('discussion topic'),
        ENV.CONDITIONAL_RELEASE_ENV)

    getFormData: ->
      data = super
      dateFields = ['last_reply_at', 'posted_at', 'delayed_post_at', 'lock_at']
      dateFields.push 'todo_date' if ENV.STUDENT_PLANNER_ENABLED
      for dateField in dateFields
        data[dateField] = $.unfudgeDateForProfileTimezone(data[dateField])
      data.title ||= I18n.t 'default_discussion_title', 'No Title'
      data.discussion_type = if data.threaded is '1' then 'threaded' else 'side_comment'
      data.podcast_has_student_posts = false unless data.podcast_enabled is '1'
      data.only_graders_can_rate = false unless data.allow_rating is '1'
      data.sort_by_rating = false unless data.allow_rating is '1'
      data.allow_todo_date = '0' if data.assignment?.set_assignment is '1'
      data.todo_date = null unless data.allow_todo_date is '1'
      data.excluded_students = @excludeStudentsView.getExcludedStudents()
      data.bulk_unassign = @unassignStudentsView.getExcludedStudents()

      unless ENV?.IS_LARGE_ROSTER
        data = @groupCategorySelector.filterFormData data

      assign_data = data.assignment
      delete data.assignment

      if assign_data?.points_possible
        # this happens before validation, so we better validate it here
        if numberHelper.validate(assign_data.points_possible)
          assign_data.points_possible = numberHelper.parse(assign_data.points_possible)
      if assign_data?.peer_review_count
        if numberHelper.validate(assign_data.peer_review_count)
          assign_data.peer_review_count = numberHelper.parse(assign_data.peer_review_count)

      if assign_data?.set_assignment is '1'
        data.set_assignment = '1'
        data.assignment = @updateAssignment(assign_data)
        # code used to set delayed_post_at = locked_at = '', but that broke
        # saving a locked graded discussion.  Leaving them as they were didn't break anything
      else
        # Announcements don't have assignments.
        # DiscussionTopics get a model created for them in their
        # constructor. Delete it so the API doesn't automatically
        # create assignments unless the user checked "Use for Grading".
        # The controller checks for set_assignment on the assignment model,
        # so we can't make it undefined here for the case of discussion topics.
        data.assignment = @model.createAssignment(set_assignment: '0')

      # these options get passed to Backbone.sync in ValidatedFormView
      @saveOpts = multipart: !!data.attachment, proxyAttachment: true

      data.published = true if @shouldPublish

      data

    updateAssignment: (data) =>
      defaultDate = @dueDateOverrideView.getDefaultDueDate()
      data.lock_at = defaultDate?.get('lock_at') or null
      data.unlock_at = defaultDate?.get('unlock_at') or null
      data.due_at = defaultDate?.get('due_at') or null
      data.assignment_overrides = @dueDateOverrideView.getOverrides()
      data.only_visible_to_overrides = @dueDateOverrideView.containsSectionsWithoutOverrides()

      assignment = @model.get('assignment')
      assignment or= @model.createAssignment()
      assignment.set(data)

    removeAttachment: ->
      @model.set 'attachments', []
      @$el.append '<input type="hidden" name="remove_attachment" >'
      @$('.attachmentRow').remove()
      @$('[name="attachment"]').show().focus()

    saveFormData: =>
      if @showConditionalRelease()
        super.pipe (data, status, xhr) =>
          assignment = data.assignment if data.set_assignment
          @conditionalReleaseEditor.updateAssignment(assignment)
          # Restore expected promise values
          @conditionalReleaseEditor.save().pipe(
            => new $.Deferred().resolve(data, status, xhr).promise()
            (err) => new $.Deferred().reject(xhr, err).promise())
      else
        super

    submit: (event) =>
      event.preventDefault()
      event.stopPropagation()
      if @dueDateOverrideView.containsSectionsWithoutOverrides()
        sections = @dueDateOverrideView.sectionsWithoutOverrides()
        missingDateDialog = new MissingDateDialog
          validationFn: -> sections
          labelFn: (section) -> section.get 'name'
          success: =>
            missingDateDialog.$dialog.dialog('close').remove()
            @model.get('assignment')?.setNullDates()
            ValidatedFormView::submit.call(this)
        missingDateDialog.cancel = (e) ->
          missingDateDialog.$dialog.dialog('close').remove()

        missingDateDialog.render()
      else
        super

    fieldSelectors: _.extend({},
      AssignmentGroupSelector::fieldSelectors,
      GroupCategorySelector::fieldSelectors
    )

    saveAndPublish: (event) ->
      @shouldPublish = true
      @disableWhileLoadingOpts = {buttons: ['.save_and_publish']}
      @submit(event)

    onSaveFail: (xhr) =>
      @shouldPublish = false
      @disableWhileLoadingOpts = {}
      super(xhr)

    validateBeforeSave: (data, errors) =>
      if data.delay_posting == "0"
        data.delayed_post_at = null
      if @isTopic() && data.set_assignment is '1'
        if @assignmentGroupSelector?
          errors = @assignmentGroupSelector.validateBeforeSave(data, errors)
        validateBeforeSaveData =
          assignment_overrides: @dueDateOverrideView.getAllDates(),
          postToSIS: data.assignment.attributes.post_to_sis == '1'
        errors = @dueDateOverrideView.validateBeforeSave(validateBeforeSaveData, errors)
        errors = @_validatePointsPossible(data, errors)
        errors = @_validateTitle(data, errors)
      else
        @model.set 'assignment', @model.createAssignment(set_assignment: false)

      if !ENV?.IS_LARGE_ROSTER && @isTopic()
        errors = @groupCategorySelector.validateBeforeSave(data, errors)
      if data.allow_todo_date == '1' && data.todo_date == null
        errors['todo_date'] = [{type: 'date_required_error', message: I18n.t('You must enter a date')}]

      if @isAnnouncement()
        if data.expire_posting == "0"
          data.post_expiration_date = null
        unless data.message?.length > 0
          unless @lockedItems.content
            errors['message'] = [{type: 'message_required_error', message: I18n.t("A message is required")}]
      if @showConditionalRelease()
        crErrors = @conditionalReleaseEditor.validateBeforeSave()
        errors['conditional_release'] = crErrors if crErrors

      errors

    _validateTitle: (data, errors) =>
      post_to_sis = data.assignment.attributes.post_to_sis == '1'
      max_name_length = 256
      if post_to_sis && ENV.MAX_NAME_LENGTH_REQUIRED_FOR_ACCOUNT == true
        max_name_length = ENV.MAX_NAME_LENGTH

      validationHelper = new SisValidationHelper({
        postToSIS: post_to_sis
        maxNameLength: max_name_length
        name: data.title
        maxNameLengthRequired: ENV.MAX_NAME_LENGTH_REQUIRED_FOR_ACCOUNT
      })

      if validationHelper.nameTooLong()
        errors["title"] = [
          message: I18n.t("Title is too long, must be under %{length} characters", length: (max_name_length + 1))
        ]
      errors

    _validatePointsPossible: (data, errors) =>
      assign = data.assignment
      frozenPoints = _.contains(assign.frozenAttributes(), "points_possible")

      if !frozenPoints and assign.pointsPossible() and !numberHelper.validate(assign.pointsPossible())
        errors["assignment[points_possible]"] = [
          message: I18n.t 'points_possible_number', 'Points possible must be a number'
        ]
      errors

    showErrors: (errors) ->
      # override view handles displaying override errors, remove them
      # before calling super
      delete errors.assignmentOverrides
      if @showConditionalRelease()
        # switch to a tab with errors
        if errors['conditional_release']
          @$discussionEditView.tabs("option", "active", 1)
          @conditionalReleaseEditor.focusOnError()
        else
          @$discussionEditView.tabs("option", "active", 0)
      super(errors)

    toggleGradingDependentOptions: ->
      @toggleAvailabilityOptions()
      @toggleConditionalReleaseTab()
      @toggleTodoDateBox()

    toggleAvailabilityOptions: ->
      if @$useForGrading.is(':checked')
        @$availabilityOptions.hide()
      else
        @$availabilityOptions.show()

    showConditionalRelease: ->
      ENV.CONDITIONAL_RELEASE_SERVICE_ENABLED && !@isAnnouncement()

    toggleConditionalReleaseTab: ->
      if @showConditionalRelease()
        if @$useForGrading.is(':checked')
          @$discussionEditView.tabs("option", "disabled", false)
        else
          @$discussionEditView.tabs("option", "disabled", [1])
          @$discussionEditView.tabs("option", "active", 0)

    toggleTodoDateBox: ->
      if @$useForGrading.is(':checked')
        @$todoOptions.hide()
      else
        @$todoOptions.show()

    toggleTodoDateInput: ->
      if @$allowTodoDate.is(':checked')
        @$todoDateInput.show()
      else
        @$todoDateInput.hide()

    onChange: ->
      if @showConditionalRelease() && @assignmentUpToDate
        @assignmentUpToDate = false

    onTabChange: ->
      if @showConditionalRelease() && !@assignmentUpToDate && @conditionalReleaseEditor
        assignmentData = @getFormData().assignment?.attributes
        @conditionalReleaseEditor.updateAssignment(assignmentData)
        @assignmentUpToDate = true
      true
