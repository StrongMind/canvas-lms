#
# Copyright (C) 2013 - present Instructure, Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')
require_relative('web_conference_spec_helper')

describe BigBlueButtonConference do
  include_examples 'WebConference'

  context "big_blue_button" do
    before do
      allow(WebConference).to receive(:plugins).and_return([
        web_conference_plugin_mock("big_blue_button", {
          :domain => "bbb.instructure.com",
          :secret_dec => "secret",
        })
      ])
      user_with_communication_channel
      @conference = BigBlueButtonConference.create!(
        :title => "my conference",
        :user => @user,
        :context => course_factory
      )
    end

    it "should correctly retrieve a config hash" do
      config = @conference.config
      expect(config).not_to be_nil
      expect(config[:conference_type]).to eql('BigBlueButton')
      expect(config[:class_name]).to eql('BigBlueButtonConference')
    end

    it "should correctly generate join urls" do
      expect(@conference.config).not_to be_nil

      # set some vars so it thinks it's been created and doesn't do an api call
      @conference.conference_key = 'test'
      @conference.settings[:admin_key] = 'admin'
      @conference.settings[:user_key] = 'user'
      @conference.save

      params = {:fullName => user_factory.name, :meetingID => @conference.conference_key, :userID => user_factory.id}
      admin_params = params.merge(:password => 'admin').to_query
      user_params = params.merge(:password => 'user').to_query
      expect(@conference.admin_join_url(@user)).to eql("https://bbb.instructure.com/bigbluebutton/api/join?#{admin_params}&checksum=" + Digest::SHA1.hexdigest("join#{admin_params}secret"))
      expect(@conference.participant_join_url(@user)).to eql("https://bbb.instructure.com/bigbluebutton/api/join?#{user_params}&checksum=" + Digest::SHA1.hexdigest("join#{user_params}secret"))
    end

    it "should confirm valid config" do
      expect(BigBlueButtonConference.new).to be_valid_config
      expect(BigBlueButtonConference.new(:conference_type => "BigBlueButton")).to be_valid_config
    end

    it "should recreate the conference" do
      expect(@conference).to receive(:send_request).with(:create, anything).and_return(true)

      expect(@conference.craft_url(@user)).to match(/\Ahttps:\/\/bbb\.instructure\.com\/bigbluebutton\/api\/join/)

      # load a new instance to clear out @conference_active
      @conference = WebConference.find(@conference.id)
      expect(@conference).to receive(:send_request).with(:create, anything).and_return(true)
      expect(@conference.craft_url(@user)).to match(/\Ahttps:\/\/bbb\.instructure\.com\/bigbluebutton\/api\/join/)
    end

    it "should not recreate the conference if it is active" do
      expect(@conference).to receive(:send_request).once.with(:create, anything).and_return(true)
      @conference.initiate_conference
      expect(@conference.active?).to be_truthy
      expect(@conference.craft_url(@user)).to match(/\Ahttps:\/\/bbb\.instructure\.com\/bigbluebutton\/api\/join/)
    end

    it "return nil if a request times out" do
      allow(CanvasHttp).to receive(:get).and_raise(Timeout::Error)
      expect(@conference.initiate_conference).to be_nil
    end
  end

  describe 'plugin setting recording_enabled is enabled' do
    let(:get_recordings_fixture){File.read(Rails.root.join('spec', 'fixtures', 'files', 'conferences', 'big_blue_button_get_recordings_two.json'))}
    let(:get_recordings_bulk_fixture){File.read(Rails.root.join('spec', 'fixtures', 'files', 'conferences', 'big_blue_button_get_recordings_bulk.json'))}

    before do
      allow(WebConference).to receive(:plugins).and_return([
        web_conference_plugin_mock("big_blue_button", {
          :domain => "bbb.instructure.com",
          :secret_dec => "secret",
          :recording_enabled => true,
        })
      ])
    end

    it "should have visible record user_setting" do
      expect(BigBlueButtonConference.user_setting_fields[:record][:visible].call).to be_truthy
    end

    it "should send record flag if record user_setting is set" do
      bbb = BigBlueButtonConference.new
      bbb.user_settings = { :record => true }
      bbb.user = user_factory
      bbb.context = course_factory
      bbb.save!
      expect(bbb).to receive(:send_request).with(:create, hash_including(record: "true"))
      bbb.initiate_conference
    end

    it "should not send record flag if record user setting is unset" do
      bbb = BigBlueButtonConference.new
      bbb.user_settings = { :record => false }
      bbb.user = user_factory
      bbb.context = course_factory
      bbb.save!
      expect(bbb).to receive(:send_request).with(:create, hash_including(record: "false"))
      bbb.initiate_conference
    end

    it "should properly serialize a response with no recordings" do
      bbb = BigBlueButtonConference.new
      allow(bbb).to receive(:conference_key).and_return('12345')
      bbb.user_settings = { record: true }
      bbb.user = user_factory
      bbb.context = course_factory
      bbb.save!
      response = {returncode: 'SUCCESS', recordings: "\n  ",
                  messageKey: 'noRecordings', message: 'There are not
                  recordings for the meetings'}
      allow(bbb).to receive(:send_request).and_return(response)
      expect(bbb.recordings).to eq []
    end

    describe "looking for recordings based on user setting" do
      before(:once) do
        @bbb = BigBlueButtonConference.new(user: user_factory, context: course_factory)

        # set some vars so it thinks it's been created and doesn't do an api call
        @bbb.conference_key = 'test'
        @bbb.settings[:admin_key] = 'admin'
        @bbb.settings[:user_key] = 'user'
        @bbb.save
      end

      it "doesn't look if setting is false" do
        @bbb.save
        expect(@bbb).to receive(:send_request).never
        @bbb.recordings
      end

      it "does look if setting is true" do
        @bbb.user_settings = { :record => true }
        @bbb.save
        expect(@bbb).to receive(:send_request)
        @bbb.recordings
      end
    end

    describe "delete recording" do
      before(:once) do
        @bbb = BigBlueButtonConference.new(user: user_factory, context: course_factory)
        # set some vars so it thinks it's been created and doesn't do an api call
        @bbb.conference_key = 'test'
        @bbb.settings[:admin_key] = 'admin'
        @bbb.settings[:user_key] = 'user'
        @bbb.save
      end

      it "doesn't delete anything if record_id = nil" do
        recording_id = nil
        allow(@bbb).to receive(:send_request)
        response = @bbb.delete_recording(recording_id)
        expect(response[:deleted]).to eq false
      end

      it "doesn't delete the recording if record_id is not found" do
        recording_id = ''
        allow(@bbb).to receive(:send_request).and_return({:returncode=>"SUCCESS", :deleted=>"false"})
        response = @bbb.delete_recording(recording_id)
        expect(response[:deleted]).to eq false
      end

      it "does delete the recording if record_id is found" do
        recording_id = 'abc123-xyz'
        allow(@bbb).to receive(:send_request).and_return({:returncode=>"SUCCESS", :deleted=>"true"})
        response = @bbb.delete_recording(recording_id)
        expect(response[:deleted]).to eq true
      end
    end

    describe "recording preloading" do
      it "should load up all recordings in a single api call" do
        @bbb2 = BigBlueButtonConference.create!(:context => @bbb.context, :user => @bbb.user, :user_settings => @bbb.user_settings)
        allow(@bbb).to receive(:conference_key).and_return('instructure_web_conference_somemeetingkey1')
        allow(@bbb2).to receive(:conference_key).and_return('instructure_web_conference_somemeetingkey2')

        response = JSON.parse(get_recordings_bulk_fixture, {symbolize_names: true})
        allow(BigBlueButtonConference).to receive(:send_request).and_return(response)

        BigBlueButtonConference.preload_recordings([@bbb, @bbb2])
        [@bbb, @bbb2].each{|c| expect(c).to_not receive(:send_request)} # shouldn't need to send individual requests anymore
        expect(@bbb.recordings.map{|r| r[:recording_id]}).to match_array(["somerecordingidformeeting1a", "somerecordingidformeeting1b"])
        expect(@bbb2.recordings.map{|r| r[:recording_id]}).to match_array(["somerecordingidformeeting2"])
      end
    end
  end

  describe 'plugin setting recording disabled' do
    before do
      allow(WebConference).to receive(:plugins).and_return([
        web_conference_plugin_mock("big_blue_button", {
          :domain => "bbb.instructure.com",
          :secret_dec => "secret",
          :recording_enabled => false,
        })
      ])
    end

    it "should have invisible record user_setting" do
      expect(BigBlueButtonConference.user_setting_fields[:record][:visible].call).to be_falsey
    end

    it "should not send record flag even if record user_setting is set" do
      bbb = BigBlueButtonConference.new
      bbb.user_settings = { :record => true }
      bbb.user = user_factory
      bbb.context = course_factory
      bbb.save!
      expect(bbb).to receive(:send_request).with(:create, hash_including(record: "false"))
      bbb.initiate_conference
      expect(bbb.user_settings[:record]).to be_falsey
    end
  end
end
