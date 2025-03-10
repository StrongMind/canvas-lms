
define [
  'i18n!modules'
  'jquery'
  'underscore'
  'compiled/views/DialogBaseView'
  'jst/course_settings/RelockModulesDialog'
], (I18n, $, _, DialogBaseView, template) ->

  class RelockModulesDialog extends DialogBaseView

    template: template

    renderIfNeeded: () ->
      if ENV.relock_warning == true
        @render().show()

    dialogOptions: ->
      id: 'relock_modules_dialog'
      title: I18n.t 'requirements_changed', 'Requirements Changed'
      buttons: [
        text: I18n.t 'relock_modules', 'Re-Lock Modules'
        click: @relock
      ,
        text: I18n.t 'continue', 'Continue'
        'class' : 'btn-primary'
        click: @cancel
      ]

    relock: =>
      url = "/api/v1/courses/#{ENV.COURSE_ID}/relock"
      @dialog.disableWhileLoading $.ajaxJSON(url, 'PUT', {}, => @close())
