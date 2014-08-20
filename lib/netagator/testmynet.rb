require 'uri'
require 'net/http'

# TODO:
# * make location of service optional argument

module Netagator
  class TestMyNet
    REGIONS = [:west]

    def initialize(region, bandwidth_reporter)
      @region   = region
      @reporter = bandwidth_reporter
    end

    def upload(count_of_megabytes)
      @reporter.report_while do
        raise NotImplementedError
      end
    end
    alias :egress :upload

    def download(count_of_megabytes)
      uri = URI.parse("http://#{@region}.testmy.net/download?special=1&tt=1&st=st&nfw=1&"\
                      "s=#{count_of_megabytes}MB")
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Post.new(uri)
        @reporter.report_while do
          http.request(request) do |response|
            response.read_body do |chunk|
              @reporter.bytes += chunk.bytesize
            end
          end
        end
      end
    end
    alias :ingress :download
  end
end
