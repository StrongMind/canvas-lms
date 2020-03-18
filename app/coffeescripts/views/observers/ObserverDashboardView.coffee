define [
    'backbone',
    'app/views/jst/observers/ObserverDashboard.handlebars'
], (Backbone, template) ->

    class ObserverDashboardView extends Backbone.View
        template: template

        el:
            '#observees-card': '$observees-card'

        initialize: (options) ->
            @observee = @model.get("observee")

        render: () ->
            super