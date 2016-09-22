require 'sinatra/base'
require "sinatra/reloader"
require 'octokit'
require 'pry'
require 'action_view'

require_relative '../lib/boot'

Config = Struct.new(:api_token, :target_repo, :watch_label)


class StatsBot < Sinatra::Base
  set :db, ::DB

  set :repo, Repo.first
  set :target_repo, settings.repo.target
  set :watch_label, settings.repo.watch_label
  set :github_api_token, ENV.fetch('GITHUB_API_TOKEN')

  Octokit.configure do |c|
    c.access_token = settings.github_api_token
  end

  class ViewHelper
    include ActionView::Helpers::DateHelper
  end

  def stats
    client =  Octokit::Client.new
    #text = params.fetch('text', )
    view_helper = ViewHelper.new
    pull_requests = client.issues(settings.target_repo)


    number_of_pull_requests = pull_requests.count
    pull_request_creation_dates = pull_requests.map { |p| p[:created_at] }
    pull_request_ages = pull_request_creation_dates.map { |p| Time.now - p }
    label_counts = pull_requests.flat_map { |p|  p[:labels].collect {|l| l[:name] } }.group_by(&:to_s).map { |k,v| [k, v.size] }.to_h

    oldest_age = pull_request_creation_dates.min
    newest_age = pull_request_creation_dates.max

    average_age = Time.now - (pull_request_ages.reduce(&:+) / pull_request_ages.size)
    needing_attention_count = label_counts.fetch(settings.watch_label, 0)

    stats = <<-SCARY_STATS
There are currently #{number_of_pull_requests} open pull requests.
There are currently #{needing_attention_count} PRs with the "#{settings.watch_label}" label.
The average age of these PRs is #{view_helper.time_ago_in_words(average_age)}.
The oldest is #{view_helper.time_ago_in_words(oldest_age)} old.
The newest is #{view_helper.time_ago_in_words(newest_age)} old.
    SCARY_STATS
    stats
  end

  get '/' do
    content_type :json
    {
        response_type: "in_channel",
        text:          stats
    }.to_json
  end

  post '/' do
    content_type :json
    {
        response_type: "in_channel",
        text:          stats
    }.to_json
  end
end