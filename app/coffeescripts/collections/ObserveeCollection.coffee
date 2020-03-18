define [
  'backbone'
  'compiled/models/Observee'
], (Backbone, Observee) ->

  class ObserveeCollection extends Backbone.Collection
    resourceName: 'observer_enrollments'

    url: -> super

    model: Observee