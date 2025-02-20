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

require 'pathname'
require 'yaml'
require 'open3'

module BrandableCSS
  APP_ROOT = defined?(Rails) && Rails.root || Pathname.pwd
  CONFIG = YAML.load_file(APP_ROOT.join('config/brandable_css.yml')).freeze
  BRANDABLE_VARIABLES = JSON.parse(File.read(APP_ROOT.join(CONFIG['paths']['brandable_variables_json']))).freeze

  use_compressed = (defined?(Rails) && Rails.env.production?) || (ENV['RAILS_ENV'] == 'production')
  SASS_STYLE = ENV['SASS_STYLE'] || ((use_compressed ? 'compressed' : 'nested')).freeze

  VARIABLE_HUMAN_NAMES = {
    "ic-brand-primary" => lambda { I18n.t("Primary Brand Color") },
    "ic-brand-secondary" => lambda { I18n.t("Secondary Brand Color") },
    "ic-brand-tertiary" => lambda { I18n.t("Tertiary Brand Color") },
    "ic-brand-white" => lambda { I18n.t("White Brand Color") },
    "ic-brand-shade-3" => lambda { I18n.t("Brand Shade 3 Color") },
    "ic-brand-font-color-dark" => lambda { I18n.t("Main Text Color") },
    "ic-link-color" => lambda { I18n.t("Link Color") },
    "ic-brand-button--primary-bgd" => lambda { I18n.t("Primary Button") },
    "ic-brand-button--primary-text" => lambda { I18n.t("Primary Button Text") },
    "ic-brand-button--secondary-bgd" => lambda { I18n.t("Secondary Button") },
    "ic-brand-button--secondary-text" => lambda { I18n.t("Secondary Button Text") },
    "ic-brand-button--secondary-border-color" => lambda { I18n.t("Secondary Button Border Color") },
    "ic-brand-global-nav-bgd" => lambda { I18n.t("Nav Background") },
    "ic-brand-global-nav-ic-icon-svg-fill" => lambda { I18n.t("Nav Icon") },
    "ic-brand-global-nav-ic-icon-svg-fill--active" => lambda { I18n.t("Nav Icon Active") },
    "ic-brand-global-nav-menu-item__text-color" => lambda { I18n.t("Nav Text") },
    "ic-brand-global-nav-menu-item__text-color--active" => lambda { I18n.t("Nav Text Active") },
    "ic-brand-global-nav-avatar-border" => lambda { I18n.t("Nav Avatar Border") },
    "ic-brand-global-nav-menu-item__badge-bgd" => lambda { I18n.t("Nav Badge") },
    "ic-brand-global-nav-menu-item__badge-text" => lambda { I18n.t("Nav Badge Text") },
    "ic-brand-global-nav-logo-bgd" => lambda { I18n.t("Nav Logo Background") },
    "ic-brand-header-image" => lambda { I18n.t("Nav Logo") },
    "ic-brand-watermark" => lambda { I18n.t("Watermark") },
    "ic-brand-watermark-opacity" => lambda { I18n.t("Watermark Opacity") },
    "ic-brand-favicon" => lambda { I18n.t("Favicon") },
    "ic-brand-apple-touch-icon" => lambda { I18n.t("Mobile Homescreen Icon") },
    "ic-brand-msapplication-tile-color" => lambda { I18n.t("Windows Tile Color") },
    "ic-brand-msapplication-tile-square" => lambda { I18n.t("Windows Tile: Square") },
    "ic-brand-msapplication-tile-wide" => lambda { I18n.t("Windows Tile: Wide") },
    "ic-brand-right-sidebar-logo" => lambda { I18n.t("Right Sidebar Logo") },
    "ic-brand-Login-body-bgd-color" => lambda { I18n.t("Background Color") },
    "ic-brand-Login-body-bgd-image" => lambda { I18n.t("Background Image") },
    "ic-brand-Login-body-bgd-shadow-color" => lambda { I18n.t("Body Shadow") },
    "ic-brand-Login-logo" => lambda { I18n.t("Login Logo") },
    "ic-brand-Login-Content-bgd-color" => lambda { I18n.t("Top Box Background") },
    "ic-brand-Login-Content-border-color" => lambda { I18n.t("Top Box Border") },
    "ic-brand-Login-Content-inner-bgd" => lambda { I18n.t("Inner Box Background") },
    "ic-brand-Login-Content-inner-border" => lambda { I18n.t("Inner Box Border") },
    "ic-brand-Login-Content-inner-body-bgd" => lambda { I18n.t("Form Background") },
    "ic-brand-Login-Content-inner-body-border" => lambda { I18n.t("Form Border") },
    "ic-brand-Login-Content-label-text-color" => lambda { I18n.t("Login Label") },
    "ic-brand-Login-Content-password-text-color" => lambda { I18n.t("Login Link Color") },
    "ic-brand-Login-footer-link-color" => lambda { I18n.t("Login Footer Link") },
    "ic-brand-Login-footer-link-color-hover" => lambda { I18n.t("Login Footer Link Hover") },
    "ic-brand-Login-instructure-logo" => lambda { I18n.t("Login Instructure Logo") }
  }.freeze

  GROUP_NAMES = {
    "global_branding" => lambda { I18n.t("Global Branding") },
    "global_navigation" => lambda { I18n.t("Global Navigation") },
    "watermarks" => lambda { I18n.t("Watermarks & Other Images") },
    "login" => lambda { I18n.t("Login Screen") }
  }.freeze

  HELPER_TEXTS = {
    "ic-brand-header-image" => lambda { I18n.t("Accepted formats: svg, png, jpg, gif") },
    "ic-brand-watermark" => lambda { I18n.t("This image appears as a background watermark to your page. Accepted formats: png, svg, gif, jpeg") },
    "ic-brand-watermark-opacity" => lambda { I18n.t("Specify the transparency of the watermark background image.") },
    "ic-brand-favicon" => lambda { I18n.t("You can use a single 16x16, 32x32, 48x48 ico file.") },
    "ic-brand-apple-touch-icon" => lambda { I18n.t("The shortcut icon for iOS/Android devices. 180x180 png") },
    "ic-brand-msapplication-tile-square" => lambda { I18n.t("558x558 png, jpg, gif (1.8x the standard tile size, so it can be scaled up or down as needed)") },
    "ic-brand-msapplication-tile-wide" => lambda { I18n.t("558x270 png, jpg, gif") },
    "ic-brand-right-sidebar-logo" => lambda { I18n.t("A full-size logo that appears in the right sidebar on the Canvas dashboard. Ideal size is 360 x 140 pixels. Accepted formats: svg, png, jpeg, gif") },
    "ic-brand-Login-body-bgd-shadow-color" => lambda { I18n.t("accepted formats: hex, rgba, rgb, hsl") }
  }.freeze

  class << self
    def variables_map
      @variables_map ||= BRANDABLE_VARIABLES.each_with_object({}) do |variable_group, memo|
        variable_group['variables'].each { |variable| memo[variable['variable_name']] = variable }
      end.freeze
    end

    def variables_map_with_image_urls
      @variables_map_with_image_urls ||= variables_map.each_with_object({}) do |(key, config), memo|
        if config['type'] == 'image'
          memo[key] = config.merge('default' => ActionController::Base.helpers.image_url(config['default']))
        else
          memo[key] = config
        end
      end.freeze
    end

    def default_variables_md5
      @default_variables_md5 ||= Digest::MD5.hexdigest(variables_map_with_image_urls.to_json)
    end

    def handle_urls(value, config, css_urls)
      return value unless config['type'] == 'image' && css_urls
      "url('#{value}')" if value.present?
    end

    # gets the *effective* value for a brandable variable
    def brand_variable_value(variable_name, active_brand_config=nil, config_map=variables_map, css_urls=false)
      config = config_map[variable_name]
      explicit_value = active_brand_config && active_brand_config.get_value(variable_name).presence
      return handle_urls(explicit_value, config, css_urls) if explicit_value
      default = config['default']
      if default && default.starts_with?('$')
        if css_urls
          return "var(--#{default[1..-1]})"
        else
          return brand_variable_value(default[1..-1], active_brand_config, config_map, css_urls)
        end
      end

      # while in our sass, we want `url(/images/foo.png)`,
      # the Rails Asset Helpers expect us to not have the '/images/', eg: <%= image_tag('foo.png') %>
      default = default.sub(/^\/images\//, '') if config['type'] == 'image'
      handle_urls(default, config, css_urls)
    end

    def computed_variables(active_brand_config=nil)
      [
        ['ic-brand-primary', 'darken', 5],
        ['ic-brand-primary', 'darken', 10],
        ['ic-brand-primary', 'darken', 15],
        ['ic-brand-primary', 'lighten', 5],
        ['ic-brand-primary', 'lighten', 10],
        ['ic-brand-primary', 'lighten', 15],
        ['ic-brand-button--primary-bgd', 'darken', 5],
        ['ic-brand-button--primary-bgd', 'darken', 15],
        ['ic-brand-button--secondary-bgd', 'darken', 5],
        ['ic-brand-button--secondary-bgd', 'darken', 15],
        ['ic-brand-font-color-dark', 'lighten', 15],
        ['ic-brand-font-color-dark', 'lighten', 30],
        ['ic-link-color', 'darken', 10],
        ['ic-link-color', 'lighten', 10],
      ].each_with_object({}) do |(variable_name, darken_or_lighten, percent), memo|
        color = brand_variable_value(variable_name, active_brand_config, variables_map_with_image_urls)
        computed_color = CanvasColor::Color.new(color).send(darken_or_lighten, percent/100.0)
        memo["#{variable_name}-#{darken_or_lighten}ed-#{percent}"] = computed_color.to_s
      end
    end

    def all_brand_variable_values(active_brand_config=nil, css_urls=false)
      variables_map.each_with_object(computed_variables(active_brand_config)) do |(key, _), memo|
        memo[key] = brand_variable_value(key, active_brand_config, variables_map_with_image_urls, css_urls)
      end
    end

    def all_brand_variable_values_as_js(active_brand_config=nil)
      "CANVAS_ACTIVE_BRAND_VARIABLES = #{all_brand_variable_values(active_brand_config).to_json};"
    end

    def all_brand_variable_values_as_css(active_brand_config=nil)
      ":root {
        #{all_brand_variable_values(active_brand_config, true).map{ |k, v| "--#{k}: #{v};"}.join("\n")}
      }"
    end

    def branded_scss_folder
      Pathname.new(CONFIG['paths']['branded_scss_folder'])
    end

    def public_brandable_css_folder
      Pathname.new('public/dist/brandable_css')
    end

    def default_brand_folder
      public_brandable_css_folder.join('default')
    end

    def default_brand_json_file
      default_brand_folder.join("variables-#{default_variables_md5}.json")
    end

    def default_brand_js_file
      default_brand_folder.join("variables-#{default_variables_md5}.js")
    end

    def default_brand_css_file
      default_brand_folder.join("variables-#{default_variables_md5}.css")
    end

    def default_json
      all_brand_variable_values.to_json
    end

    def default_js
      all_brand_variable_values_as_js
    end

    def default_css
      all_brand_variable_values_as_css
    end

    def save_default_json!
      default_brand_folder.mkpath
      default_brand_json_file.write(default_json)
      move_default_json_to_s3_if_enabled!
    end

    def save_default_js!
      default_brand_folder.mkpath
      default_brand_js_file.write(default_js)
      move_default_js_to_s3_if_enabled!
    end

    def save_default_css!
      default_brand_folder.mkpath
      default_brand_css_file.write(default_css)
      move_default_css_to_s3_if_enabled!
    end

    def save_default_files!
      save_default_json!
      save_default_js!
      save_default_css!
    end

    def move_default_json_to_s3_if_enabled!
      return unless defined?(Canvas) && Canvas::Cdn.enabled?
      s3_uploader.upload_file(public_default_json_path)
      begin
        File.delete(default_brand_json_file)
      rescue Errno::ENOENT # continue if something else deleted it in another process
      end
    end

    def move_default_js_to_s3_if_enabled!
      return unless defined?(Canvas) && Canvas::Cdn.enabled?
      s3_uploader.upload_file(public_default_js_path)
      begin
        File.delete(default_brand_js_file)
      rescue Errno::ENOENT # continue if something else deleted it in another process
      end
    end

    def move_default_css_to_s3_if_enabled!
      return unless defined?(Canvas) && Canvas::Cdn.enabled?
      s3_uploader.upload_file(public_default_css_path)
      begin
        File.delete(default_brand_css_file)
      rescue Errno::ENOENT # continue if something else deleted it in another process
      end
    end

    def s3_uploader
      @s3_uploaderer ||= Canvas::Cdn::S3Uploader.new
    end

    def public_default_json_path
      "dist/brandable_css/default/variables-#{default_variables_md5}.json"
    end

    def public_default_js_path
      "dist/brandable_css/default/variables-#{default_variables_md5}.js"
    end

    def public_default_css_path
      "dist/brandable_css/default/variables-#{default_variables_md5}.css"
    end

    def variants
      @variants ||= CONFIG['variants'].keys.freeze
    end

    def brandable_variants
      @brandable_variants ||= CONFIG['variants'].select{|_, v| v['brandable']}.map{ |k,_| k }.freeze
    end

    def combined_checksums
      if defined?(ActionController) && ActionController::Base.perform_caching && defined?(@combined_checksums)
        return @combined_checksums
      end
      file = APP_ROOT.join(CONFIG['paths']['bundles_with_deps'] + SASS_STYLE)
      if file.exist?
        @combined_checksums = JSON.parse(file.read).each_with_object({}) do |(k, v), memo|
          memo[k] = v.symbolize_keys.slice(:combinedChecksum, :includesNoVariables)
        end.freeze
      elsif defined?(Rails) && Rails.env.production?
        raise "#{file.expand_path} does not exist. You need to run #{cli} before you can serve css."
      else
        # for dev/test there might be cases where you don't want it to raise an exception
        # if you haven't ran `brandable_css` and the manifest file doesn't exist yet.
        # eg: you want to test a controller action and you don't care that it links
        # to a css file that hasn't been created yet.
        default_value = {combinedChecksum: "Error: unknown css checksum. you need to run #{cli}"}.freeze
        @combined_checksums = Hash.new(default_value).freeze
      end
    end

    # bundle path should be something like "bundles/speedgrader" or "plugins/analytics/something"
    def cache_for(bundle_path, variant)
      key = ["#{bundle_path}.scss", variant].join(CONFIG['manifest_key_seperator'])
      fingerprint = combined_checksums[key]
      raise "Fingerprint not found. #{bundle_path} #{variant}" unless fingerprint
      fingerprint
    end

    def all_fingerprints_for(bundle_path)
      variants.each_with_object({}) do |variant, object|
        object[variant] = cache_for(bundle_path, variant)
      end
    end

    def cli
      './node_modules/.bin/brandable_css'
    end

    def compile_all!
      run_cli!
    end

    def compile_brand!(brand_id, opts=nil)
      run_cli!('--brand-id', brand_id, opts)
    end

    private

    def run_cli!(*args)
      opts = args.extract_options!
      # this makes sure the symlinks to app/stylesheets/plugins/analytics, etc exist
      # so their scss files can be picked up and compiled with everything else
      require 'config/initializers/plugin_symlinks'

      command = [cli].push(*args).shelljoin
      msg = "running BrandableCSS CLI: #{command}"
      Rails.logger.try(:debug, msg) if defined?(Rails)

      percent_complete = 0
      Open3.popen2e(command) do |_stdin, stdout_and_stderr, wait_thr|
        error_output = []
        stdout_and_stderr.each do |line|
          Rails.logger.try(:debug, line.chomp!) if defined?(Rails)
          error_output.push(line)
          # This is a good-enough-for-now approximation to show the progress
          # bar in the UI.  Since we don't know exactly how many files there are,
          # it will progress towards 100% but never quite hit it until it is complete.
          # Each tick it will cut 4% of the remaining percentage. Meaning it will look like
          # it goes fast at first but then slows down, but will always keep moving.
          if opts && opts[:on_progress] && line.starts_with?('compiled ')
            percent_complete += (100.0 - percent_complete) * 0.04
            opts[:on_progress].call(percent_complete)
          end
        end
        unless wait_thr.value.success?
          STDERR.puts error_output.join("\n")
          raise("Error #{msg}")
        end
      end
    end
  end

end
