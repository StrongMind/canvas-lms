define [
    'backbone',
    'jst/observers/ObserverDashboard',
    'jsx/observers/ObserversCard',
    'react',
    'react-dom'
    ], (Backbone, template, ObserveeDashboard, React, ReactDOM) ->

    class ObserverDashboardView extends Backbone.View
      template: template

      el:
        document.getElementById('observees-card')

      initialize: (options) ->
        console.log(@collection)
        # @renderEl()
        @render()

      render: ->
        ObserveeDashboardElement = React.createElement(
          ObserveeDashboard,
          observees: @collection
        )
        ReactDOM.render(ObserveeDashboardElement, @el)


