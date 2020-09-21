#!/usr/bin/env ruby
# coding: utf-8
#
#https://github.com/slack-ruby/slack-ruby-bot
require 'slack-ruby-bot'
require_relative './octoprint_api_client'

#
# Note that you have to set OCTOPRINT_API_KEY in the environment or you
# will get authentication errors.
#
#     export OCTOPRINT_API_KEY=1234567890ABCDEF1234567890ABCDEF
#
class OctoprintBot < SlackRubyBot::Bot
  PRINTERS = [
    { name: "Prusa Blue", url: "http://10.30.0.11" },
    { name: "Prusa Purple", url: "http://10.30.0.12" },
    { name: "Prusa Red", url: "http://10.30.0.13/" },
    { name: "Ender Yellow", url: "http://10.30.0.21" },
    { name: "Ender Green", url: "http://10.30.0.22" }
  ]

  # Use the '!jobs' command in slack to get a list of active 3d printer jobs
  match /\A!jobs\z/ do |client, data, match|

    text_array = []
    PRINTERS.each do |printer|
      api_client = OctoprintApiClient.new(printer[:url])

      job = api_client.job_info
      job_progress = job['progress']

      unless job_progress.nil?
        completion = job_progress['completion']
        time_left =  job_progress['printTimeLeft']
      end

      if time_left && completion && api_client.is_on?
        time_str = Time.at(time_left).utc.strftime("%H:%M:%S")
        msg = "%s: %s (%0.2f%%)" % [printer[:name], time_str, completion]
        text_array.push msg

      else
        msg = "%s: is off" % printer[:name]
        text_array.push msg

      end
    end

    client.say(channel: data.channel, text: text_array.join("\n"))
  end
end

# Run this code if called directly from the command line instead of
# as a library.
#
if __FILE__ == $0
  OctoprintBot.run
end
