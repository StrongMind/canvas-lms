#! /usr/bin/env ruby

class EncryptSecret

  def initialize(file)
    @file = file
  end

  def parse
    File.open(@file) do |file|
      file.each_line do |line|

        key_value = line.split('=')
        key, value = key_value[0], key_value[1]
        next if value.nil?
        if encryptable_keys.include?(key)
          Dir.chdir(config_dir){
            system("`pulumi config set  --secret #{key} #{value}`")
          }
        else
          Dir.chdir(config_dir){
            system("`pulumi config set #{key} #{value}`")
          }
        end
      end
    end
  end

  def encryptable_keys
    %w(
        DB_PASS
        ENCRYPTION_KEY
        PIPELINE_PASSWORD
        S3_ACCESS_KEY_ID
        S3_ACCESS_KEY
        OUTGOING_MAIL_PASSWORD
        LAUNCH_DARKLY_SDK_KEY
        CANVAS_LMS_ADMIN_PASSWORD
      )
  end

  def config_dir
    File.join(Rails.root, 'infrastructure')
  end
end
