#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

define [
  'Backbone'
], (Backbone) ->

  class Submission extends Backbone.Model

    isGraded: =>
      @get('grade')?

    excused: =>
      @get('excused')

    hasSubmission: =>
      !!@get('submission_type')

    withoutGradedSubmission: =>
      !@hasSubmission() && !@isGraded()

    present: =>
      json = @toJSON()
      json.submitted_or_graded = !@withoutGradedSubmission()
      json
