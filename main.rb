require 'sinatra'
require 'sinatra/reloader' if development?
require 'dotenv/load'
require 'openssl'
require 'active_record'

require_relative 'models'
require_relative 'slack'

ActiveRecord::Base.establish_connection ENV['DATABASE_URL']

slack = Slack.new ENV['SLACK_TOKEN']

get '/update' do
  return 400 if params['token'] != ENV['UPDATE_TOKEN']

  users = User.all

  count = 0

  users.each do |user|
    channels = Slack.new(user.token).user_channels['channels']

    user.num_channels = channels.size
    user.save

    count += 1
  end

  "updated for #{count} users"
end

get '/' do
  redirect "https://slack.com/oauth/v2/authorize?user_scope=channels:read&client_id=#{ENV['SLACK_CLIENT_ID']}&redirect_uri=#{ENV['SLACK_REDIRECT_URI']}"
end

get '/code' do
  code = params['code']

  return 'GADZOOKS' if code.nil? or code == ''

  resp = Slack.exchange_code(code: code, redirect_uri: ENV['SLACK_REDIRECT_URI'], client_id: ENV['SLACK_CLIENT_ID'],
                             client_secret: ENV['SLACK_CLIENT_SECRET'])

  channels = Slack.new(resp['authed_user']['access_token']).user_channels['channels']

  User.new(id: resp['authed_user']['id'], token: resp['authed_user']['access_token'],
           num_channels: channels.length).save

  redirect "slack://app?team=#{resp['team']['id']}&id=#{ENV['SLACK_APP_ID']}&tab=home"
end

post '/slack/events' do
  data = request.body.read
  parsed = JSON.parse data

  return parsed['challenge'] if parsed['type'] == 'url_verification'

  return 400 unless verify_request_signature?(data, request.env['HTTP_X_SLACK_SIGNATURE'],
                                              request.env['HTTP_X_SLACK_REQUEST_TIMESTAMP'])

  users = User.order(num_channels: :desc).limit(50)

  emojis = %w[peefest yeah festpee cooll-thumbs errors seal cow-think ratscream wizard-caleb ukulele-ishan yuh ellathonk
              0-9_numbers lfg sussy hyper-dino-wave zfogg-bot radiant doot wahoo-fish ninja doge hugohu matturtle 
              orpheus-eating-chair slackbot_thonk grape-think breadthink dino-drake-yea goose-honk-left-cool]

  slack.publish_view parsed['event']['user'], {
    type: 'home',
    blocks: [
      [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: 'updated once a day (or whenever <@U013B6CPV62> feels like it)'
          },
          accessory: {
            type: 'button',
            action_id: 'add',
            text: {
              type: 'plain_text',
              text: 'add thyself'
            },
            url: (ENV['HOST']).to_s
          }
        },
        {
          type: 'divider'
        }
      ],
      users.each_with_index.map do |user, index|
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: "*#{index + 1}*: <@#{user.id}>'s in #{user.num_channels} channels :#{emojis.sample}:"
          }
        }
      end
    ].flatten
  }

  'yeet'
end

def verify_request_signature?(body, signature, timestamp)
  digest = OpenSSL::HMAC.hexdigest('SHA256', ENV['SLACK_SIGNING_SECRET'], "v0:#{timestamp}:#{body}")

  "v0=#{digest}" == signature
end
