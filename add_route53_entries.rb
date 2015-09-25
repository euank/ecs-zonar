#!/usr/bin/env ruby

# ECS Zonar is a program to handle registering ECS services and tasks into
# route53 dns entries.

require 'aws-sdk'
require_relative 'lib/ecs.rb'

ecs = Aws::ECS::Client.new
ec2 = Aws::EC2::Client.new
r53 = Aws::Route53::Client.new

dryrun = ENV['DRYRUN'] || false
debug = ENV['DEBUG'] || false
cluster = ENV['ECS_CLUSTER'] || 'default'
transcend_clusters = ENV['TRANSCEND_CLUSTERS'] || false
ttl = ENV['DNS_TTL'].nil? ? 60 : ENV['DNS_TTLE'].to_i

if transcend_clusters
  clusters = ecs.list_clusters.map(&:cluster_arns).flatten
else
  clusters = [cluster]
end

puts "Running on clusters: #{clusters}" if debug

tasks = clusters.map do |c|
  ecs.augmented_list_tasks(ec2, cluster: c, desired_status: 'RUNNING')
end.flatten

puts "Found tasks: #{tasks}" if debug

dns_ips_map = tasks.map do |task|
  next if task.last_status != "RUNNING"
  ret = Hash.new()

  task.task_definition.container_definitions.each do |cd|
    cd.environment.each do |env|
      if env.name =~ /_ECS_R53_DNS\d*/
        ret[env.value] ||= []
        ret[env.value] << task.container_instance.ec2_instance.public_ip_address
      end
      if env.name =~ /_ECS_R53_PRIVATE_DNS\d*/
        ret[env.value] ||= []
        ret[env.value] << task.container_instance.ec2_instance.private_ip_address
      end
    end
  end
  puts "Found suitable container: #{ret}" if debug && ret.size > 0
  ret
end.compact.reduce do |h1, h2|
  h1.merge(h2) { |key, lhs, rhs| rhs.nil? ? lhs : lhs + rhs }
end

if dns_ips_map.size == 0
  exit 0
end

hosted_zones = r53.list_hosted_zones.map(&:hosted_zones).flatten
dns_ips_map.each do |dns, ips|
  # Canonicalize; zones all include the trailing '.'
  dns += '.' unless dns.end_with?('.')
  zone = hosted_zones.select do |azone|
    # e.g. zone is 'example.com', match a dns of either 'example.com' or 'foobar.example.com'
    azone.name == dns || dns.end_with?('.' + azone.name)
  end.first
  if zone.nil?
    puts "Warning: Could not find matching zone for dns: " + dns
    next
  end

  if dryrun
    puts "Would add entry of: #{dns} -> #{ips.join(",")}"
    next
  end

  puts "updating entries with #{dns} = #{ips.join(", ")}" if debug
  r53.change_resource_record_sets({
    hosted_zone_id: zone.id,
    change_batch: {
      comment: "Updated by ecs-zonar",
      changes: [{
        action: 'UPSERT',
        resource_record_set: {
          name: dns,
          type: 'A',
          ttl: ttl,
          resource_records: ips.map{|i| {value: i}}
        },
      }
      ]
    }
  })
end
