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

require 'nokogiri'

class BigBlueButtonConference < WebConference
  include ActionDispatch::Routing::PolymorphicRoutes
  include CanvasRails::Application.routes.url_helpers
  after_destroy :end_meeting
  after_destroy :delete_all_recordings

  user_setting_field :record, {
    name: ->{ t('recording_setting', 'Recording') },
    description: ->{ t('recording_setting_enabled_description', 'Enable recording for this conference') },
    type: :boolean,
    default: false,
    visible: ->{ WebConference.config(BigBlueButtonConference.to_s)[:recording_enabled] },
  }

  def initiate_conference
    return conference_key if conference_key && !retouch?
    unless self.conference_key
      self.conference_key = "instructure_#{self.feed_code}".gsub(/[^a-zA-Z0-9_]/, "_")
      chars = ('a'..'z').to_a + ('0'..'9').to_a
      # create user/admin passwords for this conference. we may want to show
      # the admin passwords in the ui in case moderators need them for any
      # admin-specific functionality within the BBB ui (or we could provide
      # ui for them to specify the password/key)
      settings[:user_key] = 8.times.map{ chars[chars.size * rand] }.join
      settings[:admin_key] = 8.times.map{ chars[chars.size * rand] }.join until settings[:admin_key] && settings[:admin_key] != settings[:user_key]
    end
    settings[:record] &&= config[:recording_enabled]
    current_host = URI(settings[:default_return_url] || "http://www.instructure.com").host
    send_request(:create, {
      :meetingID => conference_key,
      :name => title,
      :voiceBridge => "%020d" % self.global_id,
      :attendeePW => settings[:user_key],
      :moderatorPW => settings[:admin_key],
      :logoutURL => (settings[:default_return_url] || "http://www.instructure.com"),
      :record => settings[:record] ? "true" : "false",
      :welcome => settings[:record] ? t("This conference may be recorded.") : "",
      "meta_canvas-recording-ready-url" => recording_ready_url(current_host)
    }) or return nil
    @conference_active = true
    save
    conference_key
  end

  def recording_ready_url(current_host = nil)
    polymorphic_url([:api_v1, context, :conferences, :recording_ready],
                    conference_id: self.id,
                    protocol: HostUrl.protocol,
                    host: HostUrl.context_host(context, current_host))
  end

  def conference_status
    if (result = send_request(:isMeetingRunning, :meetingID => conference_key)) && result[:running] == 'true'
      :active
    else
      :closed
    end
  end

  def admin_join_url(user, return_to = "http://www.instructure.com")
    join_url(user, :admin)
  end

  def participant_join_url(user, return_to = "http://www.instructure.com")
    join_url(user)
  end

  def recordings
    fetch_recordings.map do |recording|
      recording_format = recording.fetch(:playback, {}).fetch(:format, {})
      {
        recording_id:     recording[:recordID],
        duration_minutes: recording_format[:length].to_i,
        playback_url:     recording_format[:url],
      }
    end
  end

  def delete_all_recordings
    fetch_recordings.map do |recording|
      delete_recording recording[:recordID]
    end
  end

  def close
    end_meeting
    super
  end

  attr_writer :loaded_recordings
  # we can use the same API method with multiple meeting ids to load all the recordings up in one go
  # instead of making a bunch of individual calls
  def self.preload_recordings(conferences)
    filtered_conferences = conferences.select{|c| c.conference_key && c.settings[:record]}
    return unless filtered_conferences.any?

    # have a limit so we don't send a ridiculously long URL over
    limit = Setting.get("big_blue_button_preloaded_recordings_limit", "50").to_i
    filtered_conferences.each_slice(limit) do |sliced_conferences|
      meeting_ids = sliced_conferences.map(&:conference_key).join(",")
      response = send_request(:getRecordings, {
        :meetingID => meeting_ids,
      })
      result = response[:recordings] if response
      result = [] if result.is_a?(String)
      grouped_result = Array(result).group_by{|r| r[:meetingID]}
      sliced_conferences.each do |c|
        c.loaded_recordings = grouped_result[c.conference_key] || []
      end
    end
  end

  private

  def retouch?
    # If we've queried the room status recently, use that result to determine if
    # we need to recreate it.
    if !@conference_active.nil?
      return !@conference_active
    end

    # BBB removes chat rooms that have been idle fairly quickly.
    # There's no harm in "creating" a room that already exists; the api will
    # just return the room info. So we'll just go ahead and recreate it
    # to make sure we don't accidentally redirect people to an inactive room.
    return true
  end

  def join_url(user, type = :user)
    generate_request :join,
      :fullName => user.name,
      :meetingID => conference_key,
      :password => settings[(type == :user ? :user_key : :admin_key)],
      :userID => user.id
  end

  def end_meeting
    response = send_request(:end, {
      :meetingID => conference_key,
      :password => settings[(type == :user ? :user_key : :admin_key)],
      })
    response[:ended] if response
  end

  def fetch_recordings
    @loaded_recordings ||= begin
      if conference_key && settings[:record]
        response = send_request(:getRecordings, {
          :meetingID => conference_key,
          })
        result = response[:recordings] if response
        result = [] if result.is_a?(String)
        Array(result)
      else
        []
      end
    end
  end

  def delete_recording(recording_id)
    response = send_request(:deleteRecordings, {
      :recordID => recording_id,
      })
    response[:deleted] if response
  end

  def generate_request(*args)
    self.class.generate_request(*args)
  end

  def self.generate_request(action, options)
    query_string = options.to_query
    query_string << ("&checksum=" + Digest::SHA1.hexdigest(action.to_s + query_string + config[:secret_dec]))
    "https://#{config[:domain]}/bigbluebutton/api/#{action}?#{query_string}"
  end

  def send_request(*args)
    self.class.send_request(*args)
  end

  def self.send_request(action, options)
    url_str = generate_request(action, options)

    http_response = nil
    Canvas.timeout_protection("big_blue_button") do
      logger.debug "big blue button api call: #{url_str}"
      http_response = CanvasHttp.get(url_str, redirect_limit: 5)
    end

    case http_response
      when Net::HTTPSuccess
        response = xml_to_hash(http_response.body)
        if response[:returncode] == 'SUCCESS'
          return response
        else
          logger.error "big blue button api error #{response[:message]} (#{response[:messageKey]})"
        end
      else
        logger.error "big blue button http error #{http_response}"
    end
    nil
  rescue
    logger.error "big blue button unhandled exception #{$!}"
    nil
  end

  def self.xml_to_hash(xml_string)
    doc = Nokogiri::XML(xml_string)
    # assumes the top level value will be a hash
    xml_to_value(doc.root)
  end

  def self.xml_to_value(node)
    child_elements = node.element_children

    # if there are no children at all, then this is an empty node
    if node.children.empty?
      nil
    # If no child_elements, this is probably a text node, so just return its content
    elsif child_elements.empty?
      node.content
    # The BBB API follows the pattern where a plural element (ie <bars>)
    # contains many singular elements (ie <bar>) and nothing else. Detect this
    # and return an array to be assigned to the plural element.
    elsif node.name.singularize == child_elements.first.name
      child_elements.map { |child| xml_to_value(child) }
    # otherwise, make a hash of the child elements
    else
      child_elements.reduce({}) do |hash, child|
        hash[child.name.to_sym] = xml_to_value(child)
        hash
      end
    end
  end
end
