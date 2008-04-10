begin
  require 'rubygems'
  gem 'net-ssh', ">= 1.99.1"
rescue LoadError, NameError
end

require 'net/ssh'

module Capistrano
  # A helper class for dealing with SSH connections.
  class SSH
    # Patch an accessor onto an SSH connection so that we can record the server
    # definition object that defines the connection. This is useful because
    # the gateway returns connections whose "host" is 127.0.0.1, instead of
    # the host on the other side of the tunnel.
    module Server #:nodoc:
      def self.apply_to(connection, server)
        connection.extend(Server)
        connection.xserver = server
        connection
      end

      attr_accessor :xserver
    end

    # The default port for SSH.
    DEFAULT_PORT = 22

    # An abstraction to make it possible to connect to the server via public key
    # without prompting for the password. If the public key authentication fails
    # this will fall back to password authentication.
    #
    # +server+ must be an instance of ServerDefinition.
    #
    # If a block is given, the new session is yielded to it, otherwise the new
    # session is returned.
    #
    # If an :ssh_options key exists in +options+, it is passed to the Net::SSH
    # constructor. Values in +options+ are then merged into it, and any
    # connection information in +server+ is added last, so that +server+ info
    # takes precedence over +options+, which takes precendence over ssh_options.
    def self.connect(server, options={}, &block)
      methods = [ %w(publickey hostbased), %w(password keyboard-interactive) ]
      password_value = nil

      ssh_options = (server.options[:ssh_options] || {}).dup.merge(options[:ssh_options] || {}).dup
      user               = server.user || options[:user] || ssh_options[:username] || ServerDefinition.default_user
      ssh_options[:port] = server.port || options[:port] || ssh_options[:port] || DEFAULT_PORT

      begin
        connection_options = ssh_options.merge(
          :password => password_value,
          :auth_methods => ssh_options[:auth_methods] || methods.shift
        )

        connection = Net::SSH.start(server.host, user, connection_options, &block)
        Server.apply_to(connection, server)

      rescue Net::SSH::AuthenticationFailed
        raise if methods.empty? || ssh_options[:auth_methods]
        password_value = options[:password]
        retry
      end
    end
  end
end
