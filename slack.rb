require 'net/http'
require 'json'

class Slack
  def initialize(token)
    @token = token
  end

  def publish_view(user_id, view)
    ::Net::HTTP.post URI('https://slack.com/api/views.publish'), { user_id: user_id, view: view }.to_json,
                     'Content-Type' => 'application/json', 'Authorization' => "Bearer #{@token}"
  end
end
