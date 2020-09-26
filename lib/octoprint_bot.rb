#!/usr/bin/env ruby
# coding: utf-8
#
#https://github.com/slack-ruby/slack-ruby-bot
require 'slack-ruby-bot'
require 'paho-mqtt'

#
# Note that you have to set OCTOPRINT_API_KEY in the environment or you
# will get authentication errors.
#
#     export OCTOPRINT_API_KEY=1234567890ABCDEF1234567890ABCDEF
#
class OctoprintBot < SlackRubyBot::Bot
  PS1_SERVER_URL = "10.10.1.224"
  LOCALHOST_URL = "localhost"
  SERVER_PORT = 1883

  PRINTERS = [
    { name: "Prusa Blue",   topic: "3dprinting/prusa/blue" },
    { name: "Prusa Purple", topic: "3dprinting/prusa/purple" },
    { name: "Prusa Red",    topic: "3dprinting/prusa/red" },
    { name: "Ender Yellow", topic: "3dprinting/ender/yellow" },
    { name: "Ender Green",  topic: "3dprinting/ender/green" }
  ]

  def initialize
    @client = PahoMqtt::Client.new
    @message_counter = 0
    @waiting_suback = true
    @waiting_puback = true
    @mqtt_url = LOCALHOST_URL
    @mqtt_port = SERVER_PORT

    @logger = Logger.new(STDOUT)
    #@logger = Logger.new File.new('example.log', 'w')
    #@logger.level = Logger::WARN
    @logger.level = Logger::INFO
    @mutex = Mutex.new

    PRINTERS.each do |printer|
      self.subscribe(printer[:topic])
    end

    @printers = PRINTERS.clone

    @thread_mqtt = Thread.new { self.connect }

    super
  end

  def connect
    @client.on_message do |message|
      @logger.info("Message recieved on topic: #{message.topic}")
      @logger.info(">>> #{message.payload}")

      printer_id = @printers.map { |p| p[:topic] }.index(message.topic)
      @mutex.synchronize do
        @printers[printer_id][:msg] = message.payload
      end

      @message_counter += 1
    end

    ### Register a callback on suback to assert the subcription
    @client.on_suback do
      @waiting_suback = false
      @logger.info("Subscribed")
    end

    self.subscribe

    ### Register a callback for puback event when receiving a puback
    @client.on_puback do
      @waiting_puback = false
      @logger.info("Message Acknowledged")
    end

    ### Connect to the eclipse test server on port 1883 (Unencrypted mode)
    @client.connect(@mqtt_url, @mqtt_port)
  end

  # Subscribe to the base topic.
  # Not used
  def subscribe(topic = '/3dprinting/prusa/blue')
    @client.subscribe([topic, 2])

    # Waiting for the suback answer and excute the previously set
    # on_suback callback
    while @waiting_suback do
      sleep 0.001
    end
    @waiting_suback = true
  end

  # Use the '!jobs' command in slack to get a list of active 3d printer jobs
  match /\A!jobs\z/ do |client, data, match|
    text_array = []

    @mutex.synchronize do
      text_array = @printers.map { |p| p[:msg] }
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
