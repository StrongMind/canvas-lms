#
# Copyright (C) 2012 - present Instructure, Inc.
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

define [
  'compiled/models/DiscussionTopic'
  'underscore'
  'jquery'
], (DiscussionTopic, _, $) ->

  class Announcement extends DiscussionTopic

    # this is wonky, and admittitedly not the right way to do this, but it is a workaround
    # to append the query string '?only_announcements=true' to the index action (which tells
    # discussionTopicsController#index to show announcements instead of discussion topics)
    # but remove it for create/show/update/delete
    urlRoot: -> _.result(@collection, 'url').replace(@collection._stringToAppendToURL, '')

    defaults:
      is_announcement: true

    positionAfter: (otherId) ->
      reorderURL = _.result(@collection, 'url').split('discussion_topics')[0] + 'announcements/reorder_pinned'    
      pinned = @collection.where(pinned: true)
      pinned = pinned.filter((ancmt) => ancmt != this)
      otherIndex = pinned.indexOf(@collection.get(otherId))
      if otherIndex == -1
        otherIndex = pinned.length
      pinned.splice(otherIndex, 0, this)

      info = {};
      pinned.forEach((ancmt, idx) => info[ancmt.attributes.id] = idx + 1)

      $.ajax
        context: @
        type: 'POST'
        data: announcements: info
        url: reorderURL
        dataType: "json"
        success: (response) ->
          @collection.reset(pinned.concat(@collection.where(pinned: false)))
          return
        error: (response) ->
          @collection.reset(@collection.map())
          return
