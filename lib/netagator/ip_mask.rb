#!/usr/bin/env ruby

require 'ipaddr'

class IPAddr
    def network_addr( to_s=true )
        to_s and return _to_string( @addr )
        return @addr
    end
    def network_mask( to_s=true )
        to_s and return _to_string( @mask_addr )
        return @mask_addr
    end
    def mask_bits()
        i = 0
        a = @mask_addr
        while( a & 1 == 0 )
            a >>= 1
            i += 1
        end
        return 32 - i
    end
    def broadcast_addr( to_s=true )
        ipv6? and raise( "Unable to determine broadcast for IPv6 address" )
        b = @addr | (~@mask_addr & 0xffffffff)
        to_s and return _to_string( b )
        return b
    end
    def to_in_addr( str )
        return in_addr( str )
    end
end

if( ARGV.empty? or ARGV.include?( '-h' ) or ARGV.include?( '--help' ))
    puts <<EOF

usage: iphelp <arg>

    This tool assists in determining what network a given <arg>
    represents. It also shows all the IP information in both decimal
    and hexidecimal to help matching forms that are not printed in a
    more human readable fashion.

    The input <arg> can be any of the following example forms:

      1.1.1.1
      1.1.1.1/24
      1.1.1.1/255.255.255.0
      16843009
      0x01010101

    Note that the slash notation requires a "real" dotted-quad IP
    address (i.e. you can't supply a decimal or hexidecimal value with
    a slash).

EOF
# '

    exit
end

ARGV.each do |arg|
    case( arg )
        when /^0x[[:xdigit:]]+$/ then arg = arg.hex()
        when /^\d+$/ then arg = arg.to_i()
    end

    a = IPAddr.new( arg, Socket::AF_INET )

    format = "%-10s %-15s (%d/0x%08x)\n"

    if( arg.kind_of?( Bignum ) or arg.kind_of?( Fixnum ))
        ip = a.to_s()
        ip_only = true
    elsif( arg =~ /^(.+)\// )
        ip = $1
    else
        ip = arg
        ip_only = true
    end

    printf( format, 'IP:',
            ip, a.to_in_addr(ip), a.to_in_addr(ip) )

    ip_only and break

    printf( format, "mask (#{a.mask_bits}):",
            a.network_mask, a.network_mask(false), a.network_mask(false) )
    printf( format, 'network:',
            a.network_addr, a.network_addr(false), a.network_addr(false) )
    printf( format, 'broadcast:',
            a.broadcast_addr, a.broadcast_addr(false), a.broadcast_addr(false) )
    printf( "%-10s %s\n", 'addresses:',
            (a.broadcast_addr(false) - a.network_addr(false) - 1 ).
                to_s.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2'))
end
