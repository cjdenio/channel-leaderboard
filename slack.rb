require 'net/http'
require 'json'

class Slack
  def initialize(token)
    @token = token
  end

  def publish_view(user_id, view)
    Net::HTTP.post URI('https://slack.com/api/views.publish'), { user_id: user_id, view: view }.to_json,
                   'Content-Type' => 'application/json', 'Authorization' => "Bearer #{@token}"
  end

  def user_channels(limit = 1000)
    uri = URI 'https://slack.com/api/users.conversations'
    uri.query = URI.encode_www_form limit: limit, types: 'public_channel'

    JSON.parse Net::HTTP.get(uri, Authorization: "Bearer #{@token}")
  end

  def self.exchange_code(code:, redirect_uri:, client_id:, client_secret:)
    resp = Net::HTTP.post_form URI('https://slack.com/api/oauth.v2.access'), code: code, redirect_uri: redirect_uri,
                                                                             client_id: client_id, client_secret: client_secret

    JSON.parse resp.body
  end
end
