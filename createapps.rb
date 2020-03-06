require 'httparty'

DOMAIN="localhost"
CONSUMER_KEY = "Test-Key"
SHARED_SECRET = "A0FFB6DE-F911-4B57-AD6B-05CB8E078D33"
ACCESS_TOKEN = '61zxl7oxzlMPbAwk9zBZECoF4Vweiz7PSGUrs9bIuZeDFVFTtFndXSVjnfY7xcRw'
SCHOOL_ACCOUNT_ID = 1
def create_apps
  [
    {
        name: 'Maven Azure',
        consumer_key: CONSUMER_KEY,
        shared_secret: SHARED_SECRET,
        url: 'https://mavenltiprovider.azurewebsites.net/launch/tool/smartassessment-v2/',
        domain: 'mavenltiprovider.azurewebsites.net',
        privacy_level: 'public'
    },
    {
        name: 'StrongMind LTI Atlas',
        consumer_key: CONSUMER_KEY,
        shared_secret: SHARED_SECRET,
        url: 'https://courseware-lti.azurewebsites.net',
        domain: 'courseware-lti.azurewebsites.net',
        privacy_level: 'public'
    },
    {
        name: 'StrongMind LTI H2',
        consumer_key: CONSUMER_KEY,
        shared_secret: SHARED_SECRET,
        url: 'https://h2.flipswitch.com',
        domain: 'h2.flipswitch.com',
        privacy_level: 'public'
    },
    {
      name: 'StrongMind LTI Maven',
      consumer_key: CONSUMER_KEY,
      shared_secret: SHARED_SECRET,
      url: 'https://ltiprovider.strongmind.com/launch/tool/smartassessment/%5BAssessmentID%5D',
      domain: 'ltiprovider.strongmind.com',
      privacy_level: 'public'
    }
  ].each do |app|

    auth = { "Authorization" => "Bearer #{ACCESS_TOKEN}" }
    puts HTTParty.post(
      "http://#{DOMAIN}:3000/api/v1/accounts/#{SCHOOL_ACCOUNT_ID}/external_tools",
      body: app,
      headers: auth
    )
  end
end

create_apps