namespace :strongmind do
  desc "Upload courseware assets to S3"
  task :upload_assets => :environment do
    CanvasShimAssetUploader.new.upload!
  end

  desc "Reset EULA accepted"
  task :reset_eula_accepted => :environment do
    User.find_each do |user|
      if user.preferences[:accepted_terms]
        accepted_at = user.preferences[:accepted_terms]
        puts "#{user.id}, #{accepted_at}"
        csv = CSV.open('/tmp/reset_eula.log', 'a+')
        csv << [user.id, accepted_at]
        csv.close
        user.preferences[:accepted_terms] = nil;
        user.save
      end
    end
  end

end
