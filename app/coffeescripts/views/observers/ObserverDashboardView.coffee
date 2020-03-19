define [
    'backbone',
    'jsx/observers/ObserverDashboard',
    'react',
    'react-dom'
    ], (Backbone, template, ObserverDashboard, React, ReactDOM) ->

    class ObserverDashboardView extends Backbone.View
      template: template

      el:
        document.getElementById('observer-dashboard-container')

      initialize: (options) ->
        console.log(@collection)
        @render()

      render: ->
        ObserverDashboardElement = React.createElement(
          ObserverDashboard,
          observees: @collection
        )
        ReactDOM.render(ObserverDashboardElement, @el)


