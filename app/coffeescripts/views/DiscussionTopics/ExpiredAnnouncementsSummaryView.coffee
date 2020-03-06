define [
  'i18n!discussion_topics'
  'Backbone'
  'jquery'
  'compiled/views/LockIconView',
  'jst/DiscussionTopics/ExpiredView'
  'jst/_avatar'
], (I18n, Backbone, $, LockIconView, template) ->

  class ExpiredAnnouncementsSummaryView extends Backbone.View

    tagName: 'li'
    template: template

    @child 'lockIconView', '[data-view=lock-icon]'

    attributes: ->
      'class': "discussion-topic #{if @model.selected then 'selected' else '' }"
      'data-id': @model.id
      'role': "listitem"

    events:
      'change .toggleSelected' : 'toggleSelected'
      'click' : 'openOnClick'
      'click .icon-lock':  'toggleLocked'
      'click .icon-trash': 'onDelete'
      'click .individual-pin': 'togglePinned'

    els:
      '.discussion-actions .al-trigger' : '$gearButton'

    # Public: I18n translations.
    messages:
      confirm: I18n.t('Are you sure you want to delete this announcement?')
      deleteSuccessful: I18n.t('flash.removed', 'Announcement successfully deleted.')
      deleteFail: I18n.t('flash.fail', 'Announcement deletion failed.')

    initialize: ->
      @lockIconView = false
      if ENV.permissions.manage_content
        @lockIconView = new LockIconView({
          model: @model,
          unlockedText: I18n.t("%{name} is unlocked. Click to lock.", name: @model.get('title')),
          lockedText: I18n.t("%{name} is locked. Click to unlock", name: @model.get('title')),
          course_id: ENV.COURSE_ID,
          content_id: @model.get('id'),
          content_type: 'discussion_topic'
        })
      super
      @model.on 'change reset', @render, this
      @model.on 'destroy', @remove, this
      @prevEl = null

    toJSON: ->
      json = super
      Object.assign json,
        permissions: Object.assign @options.permissions, json.permissions
        selected: @model.selected
        unread_count_tooltip: (I18n.t 'unread_count_tooltip', {
          zero: 'No unread replies.'
          one: '1 unread reply.'
          other: '%{count} unread replies.'
        }, count: @model.get('unread_count'))

        reply_count_tooltip: (I18n.t 'reply_count_tooltip', {
          zero: 'No replies.',
          one: '1 reply.',
          other: '%{count} replies.'
        }, count: @model.get('discussion_subentry_count'))

        summary: $.trim(@model.summary())

    render: ->
      super
      @$el.attr @attributes()
      this

    afterRender: ->
      $('.discussion-summary').each (index, item) ->
        if item.offsetHeight < item.scrollHeight
          $(this).addClass('truncated-summary')

    toggleSelected: ->
      @model.selected = !@model.selected
      @model.trigger 'change:selected'
      @$el.toggleClass 'selected', @model.selected

    toggleLocked: (e) =>
      e.preventDefault()
      e.stopPropagation()
      locked = !@model.get('locked')
      @model.save({locked: locked}, { success: (model, response, options) =>
        @$gearButton.focus()
      })

    onDelete: (e) =>
      e.preventDefault()
      e.stopPropagation()
      if confirm(@messages.confirm)
        @preservePrevItem()
        @delete()
        @goToPrevItem()
      else
        @$gearButton.focus()

    togglePinned: (e) =>
      e.preventDefault()
      e.stopPropagation()

      unpinning = ($(".discussion-topic[data-id=" + @model.id + "]").hasClass("pinned-announcement"))

      $.ajax({
        url: "/api/v1/courses/" + ENV.COURSE_ID + "/announcements/bulk_pin",
        data: {"announcement_ids[]": [@model.id], unpin: unpinning},
        type: 'POST',
        dataType: "json",
        success: (response) ->
          reordered = []
          children = $('.discussionTopicIndexList').children()

          $('.discussionTopicIndexList').children().each (child) ->
            childID = $(this).data("id")
            pinned = false
            idx = response.findIndex (resp) ->
                    resp.discussion_topic.id == childID

            if response[idx] && response[idx].discussion_topic.pinned
              $(this).find(".individual-pin").text("Unpin")
              $(this).addClass("pinned-announcement")
              $(this).find(".discussion-info-icons-pin").removeClass("invisible-pin")
            else
              $(this).find(".individual-pin").text("Pin to Top")
              $(this).removeClass("pinned-announcement")
              $(this).find(".discussion-info-icons-pin").addClass("invisible-pin")

            reordered[idx] = $(this)

          $('.discussionTopicIndexList').children().detach()

          reordered.forEach (jq) ->
            $('.discussionTopicIndexList').append(jq)
        ,
        error: () ->
          $.flashError(
            "Something went wrong. Your announcement was not pinned."
          )
        ,
      });

    delete: ->
      @model.destroy
        success : =>
          $.flashMessage @messages.deleteSuccessful
        error : =>
          $.flashError @messages.deleteFail

    preservePrevItem: ->
      prevEl = @$el.prev()
      if prevEl.length != 0
        @prevEl = prevEl.data("id")
      else
        @prevEl = null

    goToPrevItem: ->
      if @prevEl
        prevEl = $(".discussion-topic[data-id=\"#{@prevEl}\"]")
        prevEl.find('.al-trigger').focus()
      else
        $("#searchTerm").focus()

    openOnClick: (event) ->
      window.location = @model.get('html_url') unless $(event.target).closest(':focusable, label').length
