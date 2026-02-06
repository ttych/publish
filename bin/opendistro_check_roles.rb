#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Get cluster endpoint and credentials from environment
ELASTIC_URL = ENV['ELASTIC_URL'] || 'https://localhost:9200'
ELASTIC_USER = ENV['ELASTIC_USER']
ELASTIC_PASSWORD = ENV['ELASTIC_PASSWORD']

# Endpoints
ROLES_ENDPOINT = "#{ELASTIC_URL}/_opendistro/_security/api/roles"
ROLESMAPPING_ENDPOINT = "#{ELASTIC_URL}/_opendistro/_security/api/rolesmapping"

# Helper to fetch JSON from endpoint
def fetch_json(url)
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  req.basic_auth(ELASTIC_USER, ELASTIC_PASSWORD) if ELASTIC_USER && ELASTIC_PASSWORD
  req['Content-Type'] = 'application/json'
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  res = http.request(req)
  raise "Failed to fetch #{url}: #{res.code} #{res.body}" unless res.code.to_i == 200
  JSON.parse(res.body)
end

# Fetch roles and rolesmapping
roles = fetch_json(ROLES_ENDPOINT)
rolesmapping = fetch_json(ROLESMAPPING_ENDPOINT)

# Compare roles and rolesmapping
roles_list = roles.keys
rolesmapping_list = rolesmapping.keys

roles_without_mapping = roles_list - rolesmapping_list
rolesmapping_without_roles = rolesmapping_list - roles_list

puts "Roles with no rolesmapping:"
puts roles_without_mapping.empty? ? "None" : roles_without_mapping.join("\n")
puts ""
puts "Rolesmapping with no roles:"
puts rolesmapping_without_roles.empty? ? "None" : rolesmapping_without_roles.join("\n")
