#!/usr/bin/env ruby 

require 'bundler'
require 'octokit'
require 'pry'


require 'action_view'
require 'dotenv'
Dotenv.load

puts "Run"


Octokit.configure do |c|
  c.access_token = ENV.fetch('GITHUB_API_TOKEN')
end
client =  Octokit::Client.new

pull_requests = client.pull_requests(ENV.fetch('GITHUB_TARGET_REPO'))



number_of_pull_requests = pull_requests.count
pull_request_ages = pull_requests.map { |p| Time.now - p[:created_at] }

oldest_pr = pull_requests.min_by {|p| p[:created_at] }
newest_pr = pull_requests.max_by {|p| p[:created_at] }

now_time = Time.now

average_age = now_time - (pull_request_ages.reduce(&:+) / pull_request_ages.size)
oldest_age = oldest_pr[:created_at]
newest_age = newest_pr[:created_at]
needing_attention_count = 999



include ActionView::Helpers::DateHelper
stats = <<-SCARY_STATS
There are currently #{number_of_pull_requests} open pull requests.
The average age of these PRs is #{time_ago_in_words(average_age)}.
There are currently #{needing_attention_count} PRs with the "Reviewer Requested" label.
The oldest is #{time_ago_in_words(oldest_age)} old.
The newest is #{time_ago_in_words(newest_age)} old.
SCARY_STATS


puts stats

#binding.pry

