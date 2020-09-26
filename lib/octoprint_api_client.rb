#!/usr/bin/env ruby
# coding: utf-8
#
# Lifted heavily from
# https://github.com/dougbrion/OctoRest/blob/master/octorest/client.py
#
# Faraday Usage
# https://lostisland.github.io/faraday/usage/
#
require 'faraday'
require 'json'

class OctoprintApiClient
  DEFAULT_HEADERS = {"User-Agent"=>"OctoprintApiClient v0.1",
                     'Content-Type' => 'application/json'}

  attr_reader :url

  # @param url [String]
  # @param apikey [String] Hexidecimal all-caps 32 char string
  # @param session [Faraday::Connection] permit the API client to extend an
  #    existing session.
  def initialize(url = nil, apikey = nil, session = nil)
    @url = url || "http://10.30.0.13"
    @session = session
    @apikey = apikey || ENV["OCTOPRINT_API_KEY"]

    if @session.nil?
      @session = Faraday.new(url: url, headers: DEFAULT_HEADERS)
    end

    if @apikey
      self.load_api_key(@apikey)
    end
  end

  # Add the API key to all HTTP request headers
  #
  # @param apikey [String] Hexidecimal all-caps 32 char string
  # @return [true]
  def load_api_key(apikey)
    if apikey.nil?
      raise "Required argument 'apikey' not found or empty"
    end
    unless apikey.respond_to?(:to_s)
      raise "Invalid apikey argument: {apikey.inspect}"
    end

    @session.headers['X-Api-Key'] = apikey.to_s

    return true
  end

  # A wrapper around the Faraday#get method for querying endpoints that
  # return content (use the Faraday#get directly for endpoints that respond
  # with status codes)
  #
  # @param path [String] the url path, like "api/job"
  # @param params [Hash] not used here
  def get(path, params = nil)
    uri = URI.join(@url, path)
    resp = self.session.get(uri)

    if check_response(resp, uri)
      return JSON.parse(resp.body)
    end
  end

  # Make sure the response status code was 20x, raise otherwise
  #
  # @param resp [Faraday::Response] The response object
  # @return [true]
  def check_response(resp, uri)
    status = resp.status
    unless (200 <= status) && (status < 210)
      error = resp.body
      msg = "Reply for %s was not OK: %s (%s)" % [uri, error, status]
      raise msg
    end
    return true
  end

  # Retrieve information about the current job
  # http://docs.octoprint.org/en/master/api/job.html#retrieve-information-about-the-current-job
  #
  # Retrieve information about the current job (if there is one)
  def job_info
    return get('/api/job')
  end

  # While the Prusa printers are always on, ender printers will return a
  # 403 code if the printer is off and the job endpoint is queried.
  #
  # @return [Boolean] true if the Ender printer is turned on, false if off
  def is_on?
    uri = URI.join(@url, '/api/job')
    resp = @session.get(uri)
    return 403 == resp.status ? false : true
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
  PRINTERS = [
    { name: "Prusa Blue",   url: "http://10.30.0.11" },
    { name: "Prusa Purple", url: "http://10.30.0.12" },
    { name: "Prusa Red",    url: "http://10.30.0.13" },
    { name: "Ender Yellow", url: "http://10.30.0.21" },
    { name: "Ender Green",  url: "http://10.30.0.22" }
  ]

  printers.each do |printer|
    api_client = OctoprintApiClient.new(printer[:url], printer[:apikey])

    job_info = api_client.job_info
    completion = job_info['progress']['completion']
    time_left = job_info['progress']['printTimeLeft']

    if time_left && completion && api_client.is_on?
      msg = "%s: %d seconds (%0.2f%%)" % [printer[:name], time_left, completion]
      puts msg

    else
      msg = "%s: is off" % printer[:name]
      puts msg

    end

  end

end
