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

# --- Additional Checks ---

# Fetch all indices in the cluster
def fetch_indices
  indices_url = "#{ELASTIC_URL}/_cat/indices?format=json"
  uri = URI(indices_url)
  req = Net::HTTP::Get.new(uri)
  req.basic_auth(ELASTIC_USER, ELASTIC_PASSWORD) if ELASTIC_USER && ELASTIC_PASSWORD
  req['Content-Type'] = 'application/json'
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  res = http.request(req)
  raise "Failed to fetch #{indices_url}: #{res.code} #{res.body}" unless res.code.to_i == 200
  JSON.parse(res.body).map { |idx| idx['index'] }
end

def pattern_matches_index?(pattern, index)
  # Convert Elasticsearch wildcard to Ruby regex
  regex = Regexp.new('^' + pattern.gsub('.', '\\.').gsub('*', '.*').gsub('?', '.') + '$')
  !!(index =~ regex)
end

# 1. Roles with index permissions but no matching indices
begin
  indices = fetch_indices
rescue => e
  warn "Warning: Could not fetch indices: #{e}"
  indices = []
end

roles_with_index_perms = roles.select { |_, v| v['indices'] && !v['indices'].empty? }
roles_without_matching_indices = []

roles_with_index_perms.each do |role, data|
  patterns = data['indices'].flat_map { |perm| perm['index_patterns'] || [] }
  next if patterns.empty?
  matched = patterns.any? do |pat|
    indices.any? { |idx| pattern_matches_index?(pat, idx) }
  end
  roles_without_matching_indices << role unless matched
end

puts "\nRoles with index permissions but no matching indices:"
puts roles_without_matching_indices.empty? ? "None" : roles_without_matching_indices.join("\n")

# 2. Overlapping index patterns between roles
role_patterns = {}
roles_with_index_perms.each do |role, data|
  patterns = data['indices'].flat_map { |perm| perm['index_patterns'] || [] }
  role_patterns[role] = patterns.uniq
end

overlapping_groups = []
checked = {}
role_patterns.each do |role1, patterns1|
  next if checked[role1]
  group = [role1]
  role_patterns.each do |role2, patterns2|
    next if role1 == role2 || checked[role2]
    overlap = patterns1.any? do |pat1|
      patterns2.any? do |pat2|
        # Overlap if patterns are equal or one matches the other as a regex
        pat1 == pat2 || pattern_matches_index?(pat1, pat2) || pattern_matches_index?(pat2, pat1)
      end
    end
    group << role2 if overlap
  end
  if group.size > 1
    overlapping_groups << group
    group.each { |r| checked[r] = true }
  end
end

puts "\nGroups of roles with overlapping index patterns:"
if overlapping_groups.empty?
  puts "None"
else
  overlapping_groups.each_with_index do |group, i|
    puts "Group \\##{i+1}: #{group.join(', ')}"
  end
end
