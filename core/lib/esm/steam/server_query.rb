# frozen_string_literal: true

require "socket"
require "stringio"

module ESM
  module Steam
    ##
    # Asks a game server for the details Steam shows about it - its name, map, player count, and game version - over
    # Valve's A2S protocol. Arma answers on the game port plus one.
    #
    # Since December 2020 Valve requires a challenge round trip: the first A2S_INFO comes back as a four byte
    # challenge, and the query has to be repeated with those bytes appended before the server answers for real. A
    # client written before that change reads the challenge as though it were the answer and misparses it, which is
    # why this is hand rolled rather than delegated to a gem.
    #
    class ServerQuery
      class Error < StandardError; end

      # The server never answered. Common and uninteresting: the server is down, the query port is closed, or a
      # firewall is dropping the datagram.
      class Timeout < Error; end

      # The server answered with something this doesn't know how to read.
      class UnexpectedResponse < Error; end

      # Opens every unsplit Valve query and reply.
      SIMPLE_HEADER = "\xFF\xFF\xFF\xFF".b

      # Opens a reply Valve spread across several datagrams. An A2S_INFO answer fits in one, so seeing this means
      # something is wrong rather than that reassembly is needed.
      SPLIT_HEADER = "\xFF\xFF\xFF\xFE".b

      A2S_INFO = "TSource Engine Query\x00".b

      REPLY_INFO = "I"
      REPLY_CHALLENGE = "A"

      # Long enough for a server across an ocean, short enough that a dead one doesn't hold a web request open.
      DEFAULT_TIMEOUT = 2

      MAX_DATAGRAM_SIZE = 4096

      ##
      # One server's details, as A2S reports them.
      #
      Info = Data.define(
        :protocol, :name, :map, :folder, :game, :app_id, :players, :max_players, :bots, :version
      )

      class << self
        ##
        # Queries a server and returns what it says about itself.
        #
        # @param host [String] the server's address
        # @param port [Integer] the query port, which for Arma is the game port plus one
        # @param timeout [Integer, Float] seconds to wait for each of the two round trips
        #
        # @return [Info]
        #
        # @raise [Timeout] the server never answered
        # @raise [UnexpectedResponse] the server answered with something unreadable
        # @raise [Error] the address could not be reached at all
        #
        # @example
        #   ESM::Steam::ServerQuery.info(host: "127.0.0.1", port: 2303).map # => "tanoa"
        #
        def info(host:, port:, timeout: DEFAULT_TIMEOUT)
          new(host:, port:, timeout:).info
        end

        ##
        # Reads an A2S_INFO reply. Split out from the query so the wire format can be exercised without a server.
        #
        # @param datagram [String] one reply, including its header
        #
        # @return [Info]
        #
        # @raise [UnexpectedResponse] the reply isn't an unsplit A2S_INFO answer, or it ends mid field
        #
        def parse_info(datagram)
          raise UnexpectedResponse, "Reply was split across datagrams" if datagram.start_with?(SPLIT_HEADER)
          raise UnexpectedResponse, "Reply is not a Valve query reply" unless datagram.start_with?(SIMPLE_HEADER)

          kind = datagram[4]
          raise UnexpectedResponse, "Expected an info reply, got #{kind.inspect}" if kind != REPLY_INFO

          read_info(StringIO.new(datagram.byteslice(5..) || ""))
        end

        private

        # The fields A2S_INFO reports, in wire order. Everything past the version is optional extra data nothing here
        # needs, so reading stops there.
        def read_info(io)
          protocol = read_byte(io)
          name, map, folder, game = 4.times.map { read_string(io) }
          app_id = read_bytes(io, 2).unpack1("v")
          players, max_players, bots = read_bytes(io, 3).unpack("C3")

          # Server type, environment, visibility, and VAC. None of them say anything a dashboard wants.
          read_bytes(io, 4)

          Info.new(
            protocol:, name:, map:, folder:, game:, app_id:, players:, max_players:, bots:,
            version: read_string(io)
          )
        end

        # Valve sends text as null terminated UTF-8. Scrubbed rather than trusted: a server name is whatever its owner
        # typed into a config file, and one invalid byte shouldn't take down a page.
        def read_string(io)
          value = io.gets("\x00")
          raise UnexpectedResponse, "Reply ended mid string" if value.nil?

          value.chomp("\x00").force_encoding(Encoding::UTF_8).scrub
        end

        def read_bytes(io, count)
          value = io.read(count)
          raise UnexpectedResponse, "Reply ended after #{io.pos} bytes" if value.nil? || value.bytesize < count

          value
        end

        def read_byte(io)
          read_bytes(io, 1).unpack1("C")
        end
      end

      ##
      # Prepares a query against one server. Nothing touches the network until #info runs, so building one is free.
      #
      # @param host [String] the server's address
      # @param port [Integer] the query port, which for Arma is the game port plus one
      # @param timeout [Integer, Float] seconds to wait for each of the two round trips
      #
      def initialize(host:, port:, timeout: DEFAULT_TIMEOUT)
        @host = host
        @port = port
        @timeout = timeout
      end

      ##
      # Runs the query: sends A2S_INFO, answers the challenge the server replies with, and reads what comes back.
      # The socket is opened and closed here, so an instance can be asked more than once.
      #
      # @return [Info]
      #
      # @raise [Timeout] the server never answered
      # @raise [UnexpectedResponse] the server answered with something unreadable
      # @raise [Error] the address could not be reached at all
      #
      # @see .info the class method callers normally reach this through
      #
      def info
        socket = UDPSocket.new
        socket.connect(@host, @port)

        send_query(socket)
        datagram = receive(socket)

        # The challenge is the expected first answer on any current server. Repeating the query with it appended is
        # what earns the real reply.
        if datagram[4] == REPLY_CHALLENGE
          send_query(socket, challenge: datagram.byteslice(5, 4))
          datagram = receive(socket)
        end

        self.class.parse_info(datagram)
      rescue SystemCallError => e
        # An unreachable address, a closed port, and a refused datagram all arrive here. They mean the same thing to
        # a caller as a timeout does, but the message is worth keeping.
        raise Error, "#{e.class}: #{e.message}"
      ensure
        socket&.close
      end

      private

      def send_query(socket, challenge: nil)
        socket.send(SIMPLE_HEADER + A2S_INFO + challenge.to_s, 0)
      end

      def receive(socket)
        raise Timeout, "#{@host}:#{@port} did not answer within #{@timeout}s" unless socket.wait_readable(@timeout)

        socket.recvfrom(MAX_DATAGRAM_SIZE).first
      end
    end
  end
end
