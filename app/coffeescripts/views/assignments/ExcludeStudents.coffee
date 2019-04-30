define [
  'jquery'
  'Backbone'
  'underscore'
  'react'
  'react-dom'
  'jsx/assignments/ExcludeStudents',
  'jst/assignments/ExcludeStudents'
], (
  $,
  Backbone,
  _,
  React,
  ReactDOM,
  ExcludeStudents,
  ExcludeStudentsHB
) ->
    class ExcludeStudentsView extends Backbone.View
      
      template: ExcludeStudentsHB
      render: ->
        div = @$el[0]
        return unless div
        ExcludeStudentsElement = React.createElement(ExcludeStudents)
        ReactDOM.render(ExcludeStudentsElement, div)