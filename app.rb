require 'sinatra'
require 'json'
require 'httparty'
require 'dotenv'
require 'uri'
require 'text'
require 'dalli'

configure do
  Dotenv.load
  $stdout.sync = true
  if ENV['MEMCACHEDCLOUD_SERVERS']
    $cache = Dalli::Client.new(ENV['MEMCACHEDCLOUD_SERVERS'].split(','), username: ENV['MEMCACHEDCLOUD_USERNAME'], password: ENV['MEMCACHEDCLOUD_PASSWORD'])
  end
end

get '/' do
  redirect 'https://bots.gesteves.com/#frink'
end

get '/privacy' do
  @page_title = "/frink privacy policy"
  erb :privacy, layout: :application
end

get '/support' do
  @page_title = "/frink support"
  erb :support, layout: :application
end

get '/auth' do
  @page_title = "D'oh!"
  if !params[:code].nil?
    token = get_access_token(params[:code])
    if token['ok']
      @page_title = "Woohoo!"
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
    query = params[:text].strip
    if query == ''
      response = "D'oh! You have to enter a quote from The Simpsons, like `#{params[:command]} everything's comin' up Milhouse!`"
    else
      response = $cache.get(parameterize(query))
      if response.nil?
        response = search(query)
        $cache.set(parameterize(query), response, 60*60*24)
      end
    end
    status 200
    headers 'Content-Type' => 'application/json'
    body response
  else
    status 401
    body 'Unauthorized'
  end
end

private

def search(query)
  response = HTTParty.get("https://frinkiac.com/api/search?q=#{URI.escape(query)}")
  results = JSON.parse(response.body)
  if results.size == 0
    text = "D'oh! No results found for that quote."
    response_type = 'ephemeral'
  else
    best_match = results.first
    episode = best_match['Episode']
    timestamp = best_match['Timestamp']
    image, subtitle = screencap(query, episode, timestamp)
    text = "<#{image}|#{subtitle}>"
    response_type = 'in_channel'
  end
  puts text
  build_slack_response(text, response_type)
end

def screencap(query, episode, timestamp)
  response = HTTParty.get("https://frinkiac.com/api/caption?e=#{episode}&t=#{timestamp}")
  body = JSON.parse(response.body)
  episode = body['Frame']['Episode']
  timestamp = body['Frame']['Timestamp'].to_i
  subtitle = closest_subtitle(query, body['Subtitles'])
  image = "https://frinkiac.com/gif/#{episode}/#{timestamp - 1000}/#{timestamp + 1000}.gif?lines=#{URI.escape(word_wrap(subtitle, line_width: 25))}"
  return image, subtitle
end

def closest_subtitle(text, subtitles)
  white = Text::WhiteSimilarity.new
  subtitles.max { |a, b| white.similarity(a['Content'], text) <=> white.similarity(b['Content'], text) }['Content']
end

def get_access_token(code)
  response = HTTParty.get("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['SLACK_CLIENT_ID']}&client_secret=#{ENV['SLACK_CLIENT_SECRET']}&redirect_uri=#{request.scheme}://#{request.host_with_port}/auth")
  JSON.parse(response.body)
end

def build_slack_response(text, response_type)
  response = { text: text, response_type: response_type, link_names: 1 }
  response.to_json
end

def parameterize(string)
  string.gsub(/[^a-z0-9]+/i, '-').downcase
end

# Borrowed from ActionView: https://github.com/rails/rails/blob/0e50b7bdf4c0f789db37e22dc45c52b082f674b4/actionview/lib/action_view/helpers/text_helper.rb#L240-L246
def word_wrap(text, options = {})
  line_width = options.fetch(:line_width, 80)
  text.split("\n").collect! do |line|
    line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
  end * "\n"
end
