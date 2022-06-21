#
# Copyright (C) 2015 - present Instructure, Inc.
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

# This initializer is for the Sentry exception tracking system.
#
# "Raven" is the ruby library that is the client to sentry, and it's
# config file would be "config/raven.yml". If that config doesn't exist,
# nothing happens.  If it *does*, we register a callback with Canvas::Errors
# so that every time an exception is reported, we can fire off a sentry
# call to track it and aggregate it for us.
settings = ConfigFile.load("raven")

if settings.present?

  Sentry.init do |config|
    config.dsn = settings[:dsn]
    config.transport.ssl_verification = false
    # config.tags = settings.fetch(:tags, {}).merge(
    #  'canvas_revision' => Canvas.revision,
    #  'canvas_domain' => ENV['CANVAS_DOMAIN'],
    #  'node_id' => ENV['NODE']
    # )
    config.release = Canvas.revision
    #config.sanitize_fields += Rails.application.config.filter_parameters.map(&:to_s)
    #config.sanitize_credit_cards = false
    config.enabled_environments = %w[ production development ]
    config.excluded_exceptions += %w{
      AuthenticationMethods::AccessTokenError
      AuthenticationMethods::LoggedOutError
      ActionController::InvalidAuthenticityToken
      Folio::InvalidPage
      Turnitin::Errors::SubmissionNotScoredError
    }
  end

  Rails.configuration.to_prepare do
    Canvas::Errors.register!(:sentry_notification) do |exception, data|
      setting = Setting.get("sentry_error_logging_enabled", 'true')
      SentryProxy.capture(exception, data) if setting == 'true'
    end
  end
end
