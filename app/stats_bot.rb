require 'sinatra/base'
require 'octokit'
require 'pry'
require 'action_view'
require 'json'
require 'sinatra/reloader'
require 'time_difference'

require_relative '../lib/boot'

Config = Struct.new(:api_token, :target_repo, :watch_label)
Statistics = Struct.new(:open, :counts, :oldest, :newest, :average_age, :needy)

class StatsBot < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :db, ::DB

  set(:repo) { Repo.first }

  set :github_api_token, ENV.fetch('GITHUB_API_TOKEN')

  Octokit.configure do |c|
    c.access_token = settings.github_api_token
  end

  class ViewHelper
    include ActionView::Helpers::DateHelper
  end

  def stats_message(repo, type, name)
    return "Error: No repository defined" unless repo

    client =  Octokit::Client.new
    #text = params.fetch('text', )
    view_helper = ViewHelper.new

    pull_requests = client.issues(repo.target)

    pull_request_creation_dates = pull_requests.map { |p| p[:created_at] }
    pull_request_ages = pull_request_creation_dates.map { |p| Time.now - p }
    label_counts = pull_requests.flat_map { |p|  p[:labels].collect {|l| l[:name] } }.group_by(&:to_s).map { |k,v| [k, v.size] }.to_h

    statsObj = Statistics.new(
        pull_requests.count,
        pull_requests.flat_map { |p|  p[:labels].collect {|l| l[:name] } }.group_by(&:to_s).map { |k,v| [k, v.size] }.to_h,
        pull_request_creation_dates.min,
        pull_request_creation_dates.max,
        Time.now - (pull_request_ages.reduce(&:+) / pull_request_ages.size),
        label_counts.fetch(repo.watch_label, 0)
    )
    Stats.insert(
        :repo_id => repo.id,
        :source_data => pull_requests.map(&:to_h).to_json,
        :calculated => statsObj.to_h.to_json,
        :config => repo.watch_label,
        :trigger_type => type,
        :trigger_name =>  name
    )

    stats = <<-SCARY_STATS
    There are currently #{statsObj.open} open pull requests in #{repo.name}.
    There are currently #{statsObj.needy} PRs with the "#{repo.watch_label}" label.
    The average age of these PRs is #{view_helper.time_ago_in_words(statsObj.average_age)}.
    The oldest is #{view_helper.time_ago_in_words(statsObj.oldest)} old.
    The newest is #{view_helper.time_ago_in_words(statsObj.newest)} old.
    SCARY_STATS

    all_ages_in_days = pull_request_creation_dates.map do |cd|
      TimeDifference.between(cd, DateTime.now).in_days.to_i
    end.sort

    image_url = "https://chart.googleapis.com/chart?&chbh=10&cht=bvg&chs=400x75&chd=t:#{all_ages_in_days.join(',')}&chl=#{all_ages_in_days.join('|')}"

    {
        response_type: "in_channel",
        text:          stats,
        attachments:   [{
                            color: "#F35A00",
                            title:     "Ages of all PRs",
                            image_url: image_url
                        }]
    }
  end

  get '/' do
    type = 'web'

    if params[:channel_name]
      name = params[:channel_name]
      repo = Repo.for_channel(name)
    end
    unless repo
      repo = settings.repo
      name = 'default'
    end

    content_type :json
    stats_message(repo, type, name).to_json
  end

  post '/' do
    type = 'slack'

    if params[:channel_name]
      name = params[:channel_name]
      repo = Repo.for_channel(name)
      unless repo
        repo = settings.repo
        name = 'default'
      end
    end

    debug_info = if params[:text] == "info"
      ["StatsBot is configured with the following repositories"] << repos
                 end

    if ! repo && ! debug_info
      debug_info = params.map { |k,v| "#{k} = #{v}" }
    end

    content_type :json
    if repo && !debug_info
      stats_message(repo, type, name).to_json
    else
      {
          response_type: "ephemeral",
          text:          debug_info.join("\n")
      }.to_json
    end
  end

  def repos
    Repo.all.map {|r| %Q[#{r.name} at #{r.target} in channel: #{r.channels} watching label: "#{r.watch_label}"] }
  end
end
