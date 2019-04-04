require 'json'
require 'httparty'
require 'tempfile'

module Coveralls
  class API
    if ENV['COVERALLS_ENDPOINT']
      API_HOST = ENV['COVERALLS_ENDPOINT']
      API_DOMAIN = ENV['COVERALLS_ENDPOINT']
    else
      API_HOST = ENV['COVERALLS_DEVELOPMENT'] ? "localhost:3000" : "coveralls.io"
      API_PROTOCOL = ENV['COVERALLS_DEVELOPMENT'] ? "http" : "https"
      API_DOMAIN = "#{API_PROTOCOL}://#{API_HOST}"
    end

    API_BASE = "#{API_DOMAIN}/api/v1"

    def self.post_json(endpoint, hash)
      disable_net_blockers!

      Coveralls::Output.puts("#{ JSON.pretty_generate(hash) }", :color => "green") if ENV['COVERALLS_DEBUG']
      Coveralls::Output.puts("[Coveralls] Submitting to #{API_BASE}", :color => "cyan")

      url = endpoint_to_url(endpoint)
      hash = apified_hash(hash)

      response = HTTParty.post(
        url,
        body: {
          json_file: hash_to_file(hash),
        },
      )

      if response['message']
        Coveralls::Output.puts("[Coveralls] #{ response['message'] }", :color => "cyan")
      end

      if response['url']
        Coveralls::Output.puts("[Coveralls] #{ Coveralls::Output.format(response['url'], :color => "underline") }", :color => "cyan")
      end

      if response['error']
        Coveralls::Output.puts("[Coveralls] Error: #{ Coveralls::Output.format(response['error'], :color => "underline") }", :color => "red")
      end

      case response
      when Net::HTTPServiceUnavailable
        Coveralls::Output.puts("[Coveralls] API timeout occured, but data should still be processed", :color => "red")
      when Net::HTTPInternalServerError
        Coveralls::Output.puts("[Coveralls] API internal error occured, we're on it!", :color => "red")
      end
    end

    private

    def self.disable_net_blockers!
      begin
        require 'webmock'

        allow = WebMock::Config.instance.allow || []
        WebMock::Config.instance.allow = [*allow].push API_HOST
      rescue LoadError
      end

      begin
        require 'vcr'

        VCR.send(VCR.version.major < 2 ? :config : :configure) do |c|
          c.ignore_hosts API_HOST
        end
      rescue LoadError
      end
    end

    def self.endpoint_to_url(endpoint)
      "#{API_BASE}/#{endpoint}"
    end

    def self.hash_to_file(hash)
      file = nil
      Tempfile.open(['coveralls-upload', 'json']) do |f|
        f.write(hash.to_json)
        file = f
      end
      File.new(file.path, 'rb')
    end

    def self.apified_hash(hash)
      config = Coveralls::Configuration.configuration
      if ENV['COVERALLS_DEBUG'] || Coveralls.testing
        Coveralls::Output.puts "[Coveralls] Submitting with config:", :color => "yellow"
        output = JSON.pretty_generate(config).gsub(/"repo_token": ?"(.*?)"/,'"repo_token": "[secure]"')
        Coveralls::Output.puts output, :color => "yellow"
      end
      hash.merge(config)
    end
  end
end
