# frozen_string_literal: true

module TypeSafe
  module HTTP
    # Keeps one open Net::HTTP connection per scheme, host and port so that consecutive
    # requests reuse the TCP and TLS session. Net::HTTP is not thread safe, so the transport
    # holds one manager per thread.
    #
    # Connections idle for longer than IDLE_TIMEOUT are closed before reuse, and every
    # connection is dropped after a fork so child processes never share a parent's socket.
    class ConnectionManager
      IDLE_TIMEOUT = 120

      def initialize(clock: nil)
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @connections = {}
        @touched = {}
        @pid = Process.pid
      end

      # An open connection for the URI with the given timeout applied.
      def connection_for(uri, timeout:)
        clear if @pid != Process.pid
        key = key_for(uri)
        drop(key) if @connections.key?(key) && (now - @touched[key]) > IDLE_TIMEOUT

        connection = (@connections[key] ||= start(uri, timeout))
        connection.open_timeout = timeout
        connection.read_timeout = timeout
        connection.write_timeout = timeout
        @touched[key] = now
        connection
      end

      # Close and forget the connection for the URI, typically after a network error.
      def discard(uri)
        drop(key_for(uri))
      end

      # Close and forget every connection.
      def clear
        @connections.each_key.to_a.each { |key| drop(key) }
        @pid = Process.pid
      end

      def size
        @connections.size
      end

      private

      def now
        @clock.call
      end

      def key_for(uri)
        "#{uri.scheme}://#{uri.host}:#{uri.port}"
      end

      def start(uri, timeout)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.write_timeout = timeout
        http.start
      end

      def drop(key)
        connection = @connections.delete(key)
        @touched.delete(key)
        return unless connection

        begin
          connection.finish if connection.started?
        rescue IOError
          # Already closed by the server or the runtime; nothing to release.
        end
      end
    end
  end
end
