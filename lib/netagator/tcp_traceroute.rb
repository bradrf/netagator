require 'socket'
require 'ostruct'

# TODO: support IPv6

module Netagator::TcpTraceroute

  # Default values for options.
  DEFAULT_OPTIONS = {
    timeout: 5,                 # amount of time to wait on ICMP response or 3-way completion
    first_ttl: 1,               # time-to-live value of the first request
    probe_count: 3,             # number of times to probe with the same TTL
    max_ttl: 64,                # maximum time-to-live value
    max_serial_timeouts: 3,     # maximum number of timeouts in series
  }

  # Simple access to Tracer to report on routers and measure latency using TCP.
  #
  # +host+ - Destination address (name or IP)
  # +port+ - Destination port (integer)
  # +options+ - An optional dictionary to override any of the DEFAULT_OPTIONS.
  # +block+ - If a block is provided, it will be be called with info objects of recorded data.
  #           Otherwise, an array of info objects will be returned.
  def self.to(host, port, options=nil, &block)
    Tracer.new(host, port, options, &block).trace
  end

  ICMP_TYPE = {
    3 => {
      name: :destination_unreachable,
      code: {
        0 => :network_unreachable,
        1 => :host_unreachabel,
        2 => :protocol_unreachable,
        3 => :port_unreachable,
        4 => :fragmentation_needed_and_df_set,
        5 => :source_route_failed,
      }
    },
    4 => {
      name: :source_quench,
      code: {}
    },
    5 => {
      name: :redirect,
      code: {
        0 => :network,
        1 => :host,
        2 => :type_of_service_and_network,
        3 => :typeof_service_and_host,
      }
    },
    11 => {
      name: :time_exceeded,
      code: {
        0 => :time_to_live,
        1 => :fragment_reassembly,
      }
    },
    12 => {
      name: :parameter_problem,
      code: {}
    },
  }

  class Timeout < StandardError; end

  class Tracer
    def initialize(host, port, options=nil, &block)
      @opt = OpenStruct.new(DEFAULT_OPTIONS.merge(options || {}))

      @results = []
      @info_handler = block || Proc.new{|i| @results << i}

      @dst_addr, *alt_addrs = Addrinfo.getaddrinfo(host, port, :INET, :STREAM)
      if alt_addrs.any?
        Netagator.logger.warn "Alternate IP addresses found: " <<
          alt_addrs.map{|a| a.ip_address}.join(', ')
      end

      info = OpenStruct.new(ttl: 0, destination: @dst_addr)

      begin
        @icmp_sock = Socket.new(:INET, Socket::SOCK_RAW, Socket::IPPROTO_ICMP)
      rescue Errno::EPERM
        info.error = 'Listening for ICMP replies requires escalated privileges '\
        '(invoke with sudo or as root)'
      end

      @info_handler.call(info)

      if @icmp_sock
        @icmp_sock.setsockopt(Socket::Option.linger(false, 0)) # close immediately
        @icmp_sock.bind(Socket.pack_sockaddr_in(port, ''))
      end
    end

    attr_reader :results

    def trace
      ttl = @opt.first_ttl
      @serial_timeouts = 0

      while @icmp_sock &&
          ttl <= @opt.max_ttl &&
          @serial_timeouts < @opt.max_serial_timeouts

        @opt.probe_count.times do
          @info_handler.call(measure(ttl))
          break if @icmp_sock.nil?
        end

        ttl += 1
      end

      return @results
    rescue Interrupt
    ensure
      if @icmp_sock
        @icmp_sock.close
        @icmp_sock = nil
      end
    end

    # Measure the reponse at a given time-to-live (TTL) value. Returns an info object.
    def measure(ttl)
      # tcp requires a new source address for each hop to avoid waiting on the 3-way handshake
      send_sock = Socket.new(:INET, :STREAM)
      send_sock.setsockopt(Socket::Option.linger(false, 0)) # close immediately
      send_sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, ttl)
      return get_info_with(ttl, send_sock)
    ensure
      send_sock && send_sock.close
    end

    ######################################################################
    private

      def get_info_with(ttl, send_sock)
        info = OpenStruct.new(ttl: ttl)
        begin
          (data, sender, latency_ms) = timed_connect_from(send_sock)
          @serial_timeouts = 0
          info.latency_ms = latency_ms
          info.local      = send_sock.local_address
          if data == :connected
            info.host = sender
            @icmp_sock.close
            @icmp_sock = nil
          else
            info.router = sender.ip_address
            # skip past 20 bytes of IP (assuming no options...)
            itype, iclass = data.byteslice(20,2).bytes.to_a
            if message = ICMP_TYPE[itype]
              info.icmp_type  = message[:name]
              info.icmp_class = message[:code][iclass]
            else
              info.icmp_data = data.byteslice(21..-1)
            end
          end
        rescue Timeout
          info.timeout = true
          @serial_timeouts += 1
        end
        return info
      end

      def timed_connect_from(send_sock)
        started_at = Time.now
        begin
          send_sock.connect_nonblock(@dst_addr)
        rescue IO::WaitWritable, Errno::EALREADY
        end
        (recv, send, err) = IO.select([@icmp_sock], [send_sock], nil, @opt.timeout)
        latency_ms = (Time.now - started_at) * 1000
        raise Timeout if recv.nil? && send.nil?
        if send && !send.empty?
          success = [:connected, @dst_addr, latency_ms]
          begin
            send_sock.connect_nonblock(@dst_addr) # check connection failure
            return success
          rescue Errno::EISCONN
            return success
          rescue
            # connection failure, fall thru...
          end
        end
        raise 'expected receive socket to be ready' if recv.nil? || recv.empty?
        return @icmp_sock.recvfrom(1024) << latency_ms
      end

  end
end
