#! /usr/bin/env ruby
encryptable_keys =
%w(
    DB_PASS
    ENCRYPTION_KEY
    PIPELINE_PASSWORD
    S3_ACCESS_KEY_ID
    S3_ACCESS_KEY
    OUTGOING_MAIL_PASSWORD
    LAUNCH_DARKLY_SDK_KEY
    CANVAS_LMS_ADMIN_PASSWORD
    AIRBRAKE_PROJECT_KEY
    ATTENDANCE_API_KEY_V2
    DB_HOST
    DB_USER
    LAUNCH_DARKLY_API_KEY
    OUTGOING_MAIL_USER_NAME
    REDIS_SERVER
    SIS_ENROLLMENT_UPDATE_API_KEY
    STRONGMIND_INTEGRATION_KEY
    TOPIC_MICROSERVICE_API_KEY
    MASTER_PASSWORD
    MASTER_USERNAME
  )

  

file = ARGV[0]
partner = ARGV[1]

config_dir = File.join(Dir.getwd, 'infrastructure', 'partners', partner)

File.open(file) do |file|
  file.each_line do |line|

    key_value = line.split('=')
    key, value = key_value[0], key_value[1]
    next if value.nil?
    Dir.chdir(config_dir){
      system("`pulumi stack select dev`")

      if encryptable_keys.include?(key)
          system("`pulumi config set  --secret #{key} #{value}`")
      else
          system("`pulumi config set #{key} #{value}`")
      end
    }
  end
end





