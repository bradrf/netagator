module Netagator
  class BandwidthReporter
    class InProgressError < StandardError; end

    def initialize(time_between_reports=1, priority=-10, io=$stdout)
      @io = io
      @reporter = Thread.new do
        begin
          loop do
            sleep(time_between_reports)
            report("\r") if @reporting
          end
        rescue Exception => ex
          Netagator.logger.error [:bandwith_reporter, ex.message, ex.backtrace].inspect
          raise
        end
      end
      @reporter.priority = priority
    end

    attr_accessor :bytes

    def report_while(&block)
      raise InProgressError if @reporting
      @min        = nil
      @max        = 0
      @bytes      = 0
      @started_at = Time.now
      @reporting  = true
      begin
        return yield
      ensure
        @reporting = false
        report
      end
    end

    def report(ending=$/)
      elapsed = Time.now - @started_at
      bytes   = @bytes
      mbytes  = bytes / 1048576.0
      rate    = bytes / 125000.0 / elapsed # (bytes * 8) / 1000000 == megabits
      @min    = rate if @min.nil? || rate < @min
      @max    = rate if rate > @max
      @io.printf('   %0.1f Mbps [%0.1f min, %0.1f max]: %0.1f MB (%d bytes) in %0.1f seconds' << ending,
                 rate, @min, @max, mbytes, bytes, elapsed)
    end

    def kill
      @reporter.kill
    end
  end
end
