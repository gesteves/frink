require 'sinatra'
require 'json'
require 'httparty'
require 'redis'
require 'dotenv'
require 'uri'


configure do
  Dotenv.load
  $stdout.sync = true
end

get '/' do
  erb :index
end

get '/auth' do
  if !params[:code].nil?
    token = get_access_token(params[:code])
    body "Thanks! We've added the /frink command to your #{token['team_name']} team Slack."
    status 200
  else
    status 403
    body 'Nope'
  end
end

post '/search' do
  if params[:token] == ENV['SLACK_VERIFICATION_TOKEN']
    results = search(params[:text])
    if results.size == 0
      text = 'No results found!'
    else
      best_match = results.first
      episode = best_match['Episode']
      timestamp = best_match['Timestamp']
      image, subtitle = screencap(episode, timestamp)
      text = "<#{image}|#{subtitle}>"
    end
    body build_slack_response(text)
  else
    body ''
  end
end

private

def search(query)
  response = HTTParty.get("https://frinkiac.com/api/search?q=#{query}")
  JSON.parse(response.body)
end

def screencap(episode, timestamp)
  response = HTTParty.get("https://frinkiac.com/api/caption?e=#{episode}&t=#{timestamp}")
  body = JSON.parse(response.body)
  episode = body['Frame']['Episode']
  timestamp = body['Frame']['Timestamp']
  subtitle = word_wrap(body['Subtitles'][0]['Content'], line_width: 25)
  image = "https://frinkiac.com/meme/#{episode}/#{timestamp}.jpg?lines=#{URI.escape(subtitle)}"
  return image, subtitle
end

def word_wrap(text, options = {})
  line_width = options.fetch(:line_width, 80)
  text.split("\n").collect! do |line|
    line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
  end * "\n"
end

def get_access_token(code)
  response = HTTParty.get("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['SLACK_CLIENT_ID']}&client_secret=#{ENV['SLACK_CLIENT_SECRET']}&redirect_uri=#{request.scheme}://#{request.host_with_port}/auth")
  JSON.parse(response.body)
end

def build_slack_response(text)
  response = { text: text, response_type: 'in_channel' }
  response.to_json
end
