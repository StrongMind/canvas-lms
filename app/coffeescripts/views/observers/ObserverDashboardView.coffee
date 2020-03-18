define [
    'backbone',
    'jst/observers/ObserverDashboard'
], (Backbone, template) ->

    class ObserverDashboardView extends Backbone.View
        template: template

        el:
            '#observees-card': '$observees-card'

        initialize: (options) ->
            console.log(@collection)

        render: () ->
            super
