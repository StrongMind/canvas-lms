define [
    'backbone',
    'jsx/observers/ObserverDashboard',
    'react',
    'react-dom'
    ], (Backbone, ObserverDashboard, React, ReactDOM) ->

    class ObserverDashboardView extends Backbone.View
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


