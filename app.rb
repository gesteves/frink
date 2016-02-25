require 'sinatra'
require 'json'
require 'httparty'
require 'dotenv'
require 'uri'
require 'text'

configure do
  Dotenv.load
  $stdout.sync = true
end

get '/' do
  erb :index, layout: :application
end

get '/auth' do
  if !params[:code].nil?
    token = get_access_token(params[:code])
    if token['ok']
      erb :success, layout: :application
    else
      erb :fail, layout: :application
    end
  else
    erb :fail, layout: :application
  end
end

post '/search' do
  if params[:token] == ENV['SLACK_VERIFICATION_TOKEN']
    query = params[:text]
    results = search(query)
    if results.size == 0
      text = 'No results found!'
    else
      best_match = results.first
      episode = best_match['Episode']
      timestamp = best_match['Timestamp']
      image, subtitle = screencap(query, episode, timestamp)
      text = "<#{image}|#{subtitle}>"
    end
    status 200
    headers 'Content-Type' => 'application/json'
    body build_slack_response(text)
  else
    status 401
    body 'Unauthorized'
  end
end

private

def search(query)
  response = HTTParty.get("https://frinkiac.com/api/search?q=#{URI.escape(query)}")
  JSON.parse(response.body)
end

def screencap(query, episode, timestamp)
  response = HTTParty.get("https://frinkiac.com/api/caption?e=#{episode}&t=#{timestamp}")
  body = JSON.parse(response.body)
  episode = body['Frame']['Episode']
  timestamp = body['Frame']['Timestamp']
  subtitle = closest_subtitle(query, body['Subtitles'])
  image = "https://frinkiac.com/meme/#{episode}/#{timestamp}.jpg?lines=#{URI.escape(word_wrap(subtitle, line_width: 25))}"
  return image, subtitle
end

def closest_subtitle(text, subtitles)
  white = Text::WhiteSimilarity.new
  subtitles.max { |a, b| white.similarity(a['Content'], text) <=> white.similarity(b['Content'], text) }['Content']
end

# Borrowed from ActionView: https://github.com/rails/rails/blob/0e50b7bdf4c0f789db37e22dc45c52b082f674b4/actionview/lib/action_view/helpers/text_helper.rb#L240-L246
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
  response = { text: text, response_type: 'in_channel', link_names: 1 }
  response.to_json
end
