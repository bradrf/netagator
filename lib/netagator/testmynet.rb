require 'uri'
require 'net/http'

# make another one that can serve out of cloudfront or an ec2 instance

module Netagator
  class TestMyNet
    REGIONS = [:west]

    def initialize(region, bandwidth_reporter)
      @region   = region
      @reporter = bandwidth_reporter
    end

    def upload(count_of_megabytes)
      raise NotImplementedError
    end
    alias :egress :upload

    def download(count_of_megabytes)
      post_to("http://#{@region}.testmy.net/download?special=1&tt=1&st=st&nfw=1&"\
              "s=#{count_of_megabytes}MB")
    end
    alias :ingress :download

    ######################################################################
    private
      def post_to(uri, count=1)
        uri = URI.parse(uri)
        if count == 1
          Netagator.logger.debug "Downloading from #{uri.host}"
        else
          Netagator.logger.warn "*** Redirected to #{uri.host} ***"
        end
        location = nil
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Post.new(uri.request_uri)
          http.request(request) do |response|
            if response.kind_of?(Net::HTTPRedirection) && count < 3
              return post_to(response['location'], count+1)
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
