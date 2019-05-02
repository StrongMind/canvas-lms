define [
  'jquery'
  'Backbone'
  'react'
  'react-dom'
  'jsx/assignments/ExcludeStudents',
  'jst/assignments/ExcludeStudents'
], (
  $,
  Backbone,
  React,
  ReactDOM,
  ExcludeStudents,
  ExcludeStudentsTemplate
) ->
    class ExcludeStudentsView extends Backbone.View
      template: ExcludeStudentsTemplate
      setNewExcludesCollection: (newExcludes) =>
        console.log(newExcludes)
      render: ->
        div = @$el[0]
        return unless div
        ExcludeStudentsElement = React.createElement(ExcludeStudents, 
          syncWithBackbone: @setNewExcludesCollection
        )
        ReactDOM.render(ExcludeStudentsElement, div)