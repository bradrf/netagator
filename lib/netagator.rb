require 'logger'

module Netagator
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
  def self.logger=(logger)
    @logger = logger
  end
end

require_relative 'netagator/bandwidth_reporter'
require_relative 'netagator/tcp_traceroute'
require_relative 'netagator/testmynet'
