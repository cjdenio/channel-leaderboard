require 'sinatra'
require 'sinatra/reloader' if development?
require 'dotenv/load'
require 'openssl'

require_relative 'slack'

slack = Slack.new ENV['SLACK_TOKEN']

get '/' do
  puts request.env
  JSON.generate request.env
end

post '/slack/events' do
  data = request.body.read
  parsed = JSON.parse data

  return parsed['challenge'] if parsed['type'] == 'url_verification'

  return [400, 'sadge'] unless verify_request_signature?(data, request.env['HTTP_X_SLACK_SIGNATURE'],
                                                         request.env['HTTP_X_SLACK_REQUEST_TIMESTAMP'])

  slack.publish_view parsed['event']['user'], {
    type: 'home',
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: 'hi there'
        }
      }
    ]
  }
  return 'yeet'
end

def verify_request_signature?(body, signature, timestamp)
  digest = OpenSSL::HMAC.hexdigest('SHA256', ENV['SLACK_SIGNING_SECRET'], "v0:#{timestamp}:#{body}")

  "v0=#{digest}" == signature
end
