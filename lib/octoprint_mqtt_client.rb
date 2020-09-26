#!/usr/bin/env ruby
# coding: utf-8
#
#
# https://github.com/eclipse/paho.mqtt.ruby
require 'paho-mqtt'
require 'logger'
require_relative './octoprint_api_client'

### Create a simple client with default attributes
#
# A wrapper around the PahoMqtt::Client class
class OctoprintMqttClient
  PS1_SERVER_URL = "10.10.1.224"
  LOCALHOST_URL = "localhost"
  SERVER_PORT = 1883

  # Check every 5 minutes
  SLEEP_INTERVAL = 60*5

  TOPIC_NAMESPACE = "3dprinting"
  PRINTERS = [
    { name: "Prusa Blue",   url: "http://10.30.0.11", topic: "prusa/blue" },
    { name: "Prusa Purple", url: "http://10.30.0.12", topic: "prusa/purple" },
    { name: "Prusa Red",    url: "http://10.30.0.13", topic: "prusa/red" },
    { name: "Ender Yellow", url: "http://10.30.0.21", topic: "ender/yellow" },
    { name: "Ender Green",  url: "http://10.30.0.22", topic: "ender/green" }
  ]

  def initialize
    @client = PahoMqtt::Client.new
    @message_counter = 0
    @waiting_suback = true
    @waiting_puback = true

    @logger = Logger.new(STDOUT)
    #@logger = Logger.new File.new('example.log', 'w')
    #@logger.level = Logger::WARN
    @logger.level = Logger::INFO
  end

  def run
    loop do
      poll_octoprint_servers
      sleep SLEEP_INTERVAL
    end
  end

  def poll_octoprint_servers
    printers.each do |printer|
      api_client = OctoprintApiClient.new(printer[:url], printer[:apikey])

      job_info = api_client.job_info
      completion = job_info['progress']['completion']
      time_left = job_info['progress']['printTimeLeft']

      topic = "#{TOPIC_NAMESPACE}/#{printer[:topic]}"
      if time_left && completion && api_client.is_on?
        msg = "%s: %d seconds (%0.2f%%)" % [printer[:name], time_left, completion]
        @logger.info(msg)

        # Publlish a message on the printer's topic
        # with "retain == false" and "qos == 1"
        @client.publish(topic, msg, false, 1)
        while waiting_puback do
          sleep 0.001
        end
        @waiting_puback = true
      else
        msg = "%s: is off" % printer[:name]
        @logger.info(msg)

        @client.publish(topic, msg, false, 1)
        while waiting_puback do
          sleep 0.001
        end
        @waiting_puback = true
      end
    end
  end

  def connect
    @client.on_message do |message|
      @logger.info("Message recieved on topic: #{message.topic}")
      @logger.info(">>> #{message.payload}")
      @message_counter += 1
    end

    ### Register a callback on suback to assert the subcription
    @client.on_suback do
      @waiting_suback = false
      @logger.info("Subscribed")
    end

    ### Register a callback for puback event when receiving a puback
    @client.on_puback do
      @waiting_puback = false
      @logger.info("Message Acknowledged")
    end

    ### Connect to the eclipse test server on port 1883 (Unencrypted mode)
    @client.connect(LOCALHOST_URL, SERVER_PORT)
  end

  # Subscribe to the base topic.
  # Not used
  def subscribe(topic = '/3dprinting')
    @client.subscribe(['/3dprinting', 2])

    # Waiting for the suback answer and excute the previously set
    # on_suback callback
    while @waiting_suback do
      sleep 0.001
    end
    @waiting_suback = true
  end

  # Calling an explicit disconnect
  def disconnect
    @client.disconnect
  end

end

# Run this code if called directly from the command line instead of
# as a library.
#
# Note that you have to set OCTOPRINT_API_KEY in the environment or you
# will get authentication errors.
#
#     export OCTOPRINT_API_KEY=1234567890ABCDEF1234567890ABCDEF
#
if __FILE__ == $0
  client = OctoprintMqttClient.new
  client.connect
  client.subscribe
  client.run
end
