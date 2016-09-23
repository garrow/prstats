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
    There are currently #{statsObj.open} open pull requests in #{repo.name} <https://github.com/#{repo.target}/pulls|#{repo.target}>.
    There are currently #{statsObj.needy} PRs with the "#{repo.watch_label}" label.
    The average age of these PRs is #{view_helper.time_ago_in_words(statsObj.average_age)}.
    The oldest is #{view_helper.time_ago_in_words(statsObj.oldest)} old.
    The newest is #{view_helper.time_ago_in_words(statsObj.newest)} old.
    SCARY_STATS

    all_ages_in_days = pull_request_creation_dates.map do |cd|
      TimeDifference.between(cd, DateTime.now).in_days.to_i
    end.sort


    all_ages_in_weeks = pull_request_creation_dates.map do |cd|
      TimeDifference.between(cd, DateTime.now).in_weeks.ceil
    end.sort.group_by(&:itself).map {|label, values| ["#{label}w", values.count] }.to_h

    max_weeks_value = all_ages_in_weeks.values.max
    weeks_url_pie = "https://chart.googleapis.com/chart?&chxr=#{max_weeks_value}&cht=p3&chs=400x100&chd=t:#{all_ages_in_weeks.values.join(',')}&chl=#{all_ages_in_weeks.keys.join('|')}"

    weeks_url_bar = bar_chart_url(all_ages_in_weeks.values, all_ages_in_weeks.keys)

    # Response
    {
        response_type: "in_channel",
        text:          stats,
        attachments:   [
                           {
                            color:     "#F35A00",
                            title:     "Ages of all PRs",
                            image_url: bar_chart_url(all_ages_in_days, all_ages_in_days)
                        },
                        {
                             color: "#000000",
                             title:     "Age in Weeks",
                             image_url: weeks_url_bar
                         }
                       ]
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
                   RepoListMessage.new.message
                 end

    if ! repo && ! debug_info
      debug_info = {
          response_type: "ephemeral",
          text:          params.map { |k,v| "#{k} = #{v}" }.join("\n")
      }
    end

    content_type :json
    if repo && !debug_info
      stats_message(repo, type, name).to_json
    else
      debug_info.to_json
    end
  end


  # TODO - Refactor

  def bar_chart_url(values, labels)
    # days_url = "https://chart.googleapis.com/chart?&chbh=10&cht=bvg&chs=400x75&chd=t:#{all_ages_in_days.join(',')}&chl=#{all_ages_in_days.join('|')}"
    # weeks_url_bar = "https://chart.googleapis.com/chart?&chxt=x,y&chxr=1,0,#{max_weeks_value},1&chbh=a&cht=bvg&chds=0,#{max_weeks_value}&chs=400x100&chd=t:#{all_ages_in_weeks.values.join(',')}&chl=#{all_ages_in_weeks.keys.join('|')}"

    #&chxr=1,0,#{max_value},1
    #&chxr=1,0,#{max_value}

    max_value = values.max

    "https://chart.googleapis.com/chart?&chxr=1,0,#{max_value}&chxt=x,y&chbh=a&cht=bvg&chds=0,#{max_value}&chs=400x100&chd=t:#{values.join(',')}&chl=#{labels.join('|')}"
  end

end

class RepoListMessage
  def repos
    Repo.all
  end

  def message
    {
        response_type: "ephemeral",
        # response_type: "in_channel",
        text:          "StatsBot is configured with the following repositories",
        attachments: attachments
    }
  end

  def attachments
    #https://api.slack.com/docs/message-attachments
    repos.map do |repo|
      {
          title: "#{repo.name} <https://github.com/#{repo.target}|#{repo.target}>",
          fields: [

                      {title: 'Channels', value: "\##{repo.channels}", short: true},
                      {title: 'Watch Label', value: repo.watch_label, short: true},
                  ]
      }
      # %Q[#{repo.name} at #{repo.target} in channel: #{repo.channels} watching label: "#{repo.watch_label}"]
    end
  end
end
