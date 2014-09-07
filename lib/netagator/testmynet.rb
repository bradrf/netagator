require 'uri'
require 'net/http'

# make another one that can serve out of cloudfront or an ec2 instance

module Netagator
  class TestMyNet
    REGIONS = [:local, :west]

    def initialize(region, bandwidth_reporter)
      @region   = region.to_sym
      @reporter = bandwidth_reporter
    end

    def upload(count_of_megabytes)
      raise NotImplementedError
    end
    alias :egress :upload

    def download(count_of_megabytes)
      if @region == :local
        http(:get, "http://bw.gigglewax.com/#{count_of_megabytes}MB")
      else
        http(:post, "http://#{@region}.testmy.net/download?special=1&tt=1&st=st&nfw=1&"\
             "s=#{count_of_megabytes}MB")
      end
    end
    alias :ingress :download

    ######################################################################
    private
      def http(action, uri, count=1)
        http_action = action.is_a?(Class) ?
          action :
          Object.const_get("Net::HTTP::#{action.capitalize}")
        uri = URI.parse(uri)
        if count == 1
          Netagator.logger.debug("#{action.upcase} #{uri}")
        else
          Netagator.logger.warn("*** Redirected to #{uri.host} ***")
        end
        location = nil
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = http_action.new(uri.request_uri)
          http.request(request) do |response|
            if response.kind_of?(Net::HTTPRedirection) && count < 3
              return http(http_action, response['location'], count+1)
            end
            response.error! unless response.kind_of?(Net::HTTPSuccess)
            @reporter.report_while do
              response.read_body do |chunk|
                @reporter.bytes += chunk.bytesize
              end
            end
          end
        end
      end
  end
end
