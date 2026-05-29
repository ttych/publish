#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'optparse'

DEFAULT_DELAY = 5

options = {
  url: nil,
  username: nil,
  password: nil,
  ca_cert: nil,
  delay: DEFAULT_DELAY
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

  opts.on('-u', '--url URL', 'Elasticsearch cluster URL (required)') do |v|
    options[:url] = v
  end

  opts.on('-U', '--username USERNAME', 'Username for authentication') do |v|
    options[:username] = v
  end

  opts.on('-p', '--password PASSWORD', 'Password for authentication') do |v|
    options[:password] = v
  end

  opts.on('-c', '--ca-cert PATH', 'Path to CA certificate file') do |v|
    options[:ca_cert] = v
  end

  opts.on('-d', '--delay SECONDS', Integer, "Delay between polls in seconds (default: #{DEFAULT_DELAY})") do |v|
    options[:delay] = v
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit 0
  end
end

parser.parse!

if options[:url].nil?
  warn 'Error: --url is required'
  warn parser
  exit 1
end

def build_http(uri, ca_cert)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    if ca_cert
      http.ca_file = ca_cert
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    else
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end
  http
end

def build_request(path, username, password)
  req = Net::HTTP::Get.new(path)
  req['Accept'] = 'application/json'
  req.basic_auth(username, password) if username && password
  req
end

def fetch_json(http, request)
  response = http.request(request)
  unless response.is_a?(Net::HTTPSuccess)
    warn "HTTP error #{response.code}: #{response.message}"
    return nil
  end
  JSON.parse(response.body)
rescue JSON::ParserError => e
  warn "Failed to parse JSON: #{e.message}"
  nil
rescue StandardError => e
  warn "Request failed: #{e.message}"
  nil
end

def fetch_tasks(base_uri, http, username, password)
  req = build_request("#{base_uri.path.chomp('/')}/_tasks?detailed=true&group_by=none", username, password)
  data = fetch_json(http, req)
  return {} unless data

  data.dig('tasks') || {}
end

def fetch_pending_tasks(base_uri, http, username, password)
  req = build_request("#{base_uri.path.chomp('/')}/_cluster/pending_tasks", username, password)
  data = fetch_json(http, req)
  return [] unless data

  data['tasks'] || []
end

def display_tasks(tasks)
  counts = Hash.new(0)
  tasks.each do |task|
    normalized_action = task['action'].gsub(/\[.*?\]/, '')
    counts[normalized_action] += 1
  end

  if counts.any?
    counts.sort_by { |_, v| -v }.each do |action, count|
      puts format('Task %-60s: %d', action, count)
    end
  end
end

def display_pending_tasks(pending_tasks)
  counts = Hash.new(0)
  pending_tasks.each do |t|
    source = t['source'].to_s
    category = source.split('[').first.strip
    category = '(unknown)' if category.empty?
    counts[category] += 1
  end

  counts.sort_by { |_, v| -v }.each do |category, count|
    puts format('Cluster pending task %-56s: %d', category, count)
  end
end

base_uri = URI.parse(options[:url])
http = build_http(base_uri, options[:ca_cert])

loop do
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  puts "\n[#{timestamp}]"

  tasks = fetch_tasks(base_uri, http, options[:username], options[:password])
  display_tasks(tasks)

  pending = fetch_pending_tasks(base_uri, http, options[:username], options[:password])
  display_pending_tasks(pending)

  sleep options[:delay]
end
