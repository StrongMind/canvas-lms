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
  )

  
config_dir = File.join(Dir.getwd, 'infrastructure', 'partners')

file = ARGV[0]
partner = ARGV[1]

File.open(file) do |file|
  file.each_line do |line|

    key_value = line.split('=')
    key, value = key_value[0], key_value[1]
    next if value.nil?
    Dir.chdir(config_dir){
      system("`pulumi stack select #{partner}`")

      if encryptable_keys.include?(key)
          system("`pulumi config set  --secret #{key} #{value}`")
      else
          system("`pulumi config set #{key} #{value}`")
      end
    }
  end
end





