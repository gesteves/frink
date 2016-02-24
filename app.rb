require 'sinatra'
require 'json'
require 'httparty'
require 'redis'
require 'dotenv'
require 'uri'


configure do
  Dotenv.load
  $stdout.sync = true
  case settings.environment
  when :development
    uri = URI.parse('redis://localhost:6379')
  when :production
    uri = URI.parse(ENV['REDISCLOUD_URL'])
  end
  $redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
end

get '/foo' do
  'Hi.'
end

post '/search' do
  results = search(params[:query])
  if results.size == 0
    'no results found'
  else
    best_match = results.first
    episode = best_match['Episode']
    timestamp = best_match['Timestamp']
    screencap(episode, timestamp)
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
  "https://frinkiac.com/meme/#{episode}/#{timestamp}.jpg?lines=#{URI.escape(subtitle)}"
end

def word_wrap(text, options = {})
  line_width = options.fetch(:line_width, 80)
  text.split("\n").collect! do |line|
    line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
  end * "\n"
end
