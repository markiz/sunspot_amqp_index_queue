#
# This implementation is heavily inspired by
#     https://github.com/bdurand/sunspot_index_queue
#
require 'sunspot'
require 'sunspot/session_proxy/abstract_session_proxy'

module Sunspot
  module AmqpIndexQueue
    # This is a Sunspot::SessionProxy that works with {Sunspot::AmqpIndexQueue::Client}
    # class.
    #
    # Most update requests will be added to the queue and processed
    # asynchronously. The exceptions are the `remove` method with
    # a block and the `remove_all` method. These will send their commands
    # directly to Solr since the queue cannot handle delete by query.
    #
    # You should avoid calling these methods unless you know what you're doing.
    class SessionProxy < Sunspot::SessionProxy::AbstractSessionProxy
      attr_reader :client, :session

      delegate :new_search, :search, :new_more_like_this, :more_like_this, :config, :to => :session

      # Instantiate a session proxy
      #
      # @param [Sunspot::SessionProxy] session previously instantiated sunspot
      #    session or session proxy.
      # @option client_opts [String] "host" ("localhost") AMQP host name
      # @option client_opts [Integer] "port" (55672) AMQP port
      # @option client_opts [String] "user" ("guest") AMQP user name
      # @option client_opts [String] "pass" ("guest") AMQP password
      # @option client_opts [String] "vhost" ("/") AMQP vhost
      # @option client_opts [String] "sunspot_index_queue_name" ("sunspot_index_queue")
      # @option client_opts [Integer] "retry_interval" (300) time before next
      #    indexing attempt in case of failure / exception
      # @option client_opts [Integer] "max_attempts_count" (5) attempts count
      #    AMQP index queue name
      # @option client_opts [Integer] "index_delay" (0) delay in seconds between receiving
      #    a message about indexing and trying to process it
      # @api public
      def initialize(session, client_opts = {})
        @session = session
        @client = Client.new(session, client_opts)
      end

      # Does nothing in this implementation.
      def batch
        yield if block_given?
      end

      # Does nothing in this implementation.
      def commit
        # no op
      end

      # Does nothing in this implementation.
      def commit_if_delete_dirty
        # no op
      end

      # Does nothing in this implementation.
      def commit_if_dirty
        # no op
      end

      # Always returns false in this implementation.
      def delete_dirty?
        false
      end

      # Always returns false in this implementation.
      def dirty?
        false
      end

      # Queues up the index operation for later.
      def index(*objects)
        objects.flatten.each do |object|
          client.index(object)
        end
      end

      # Queues up the index operation for later.
      def index!(*objects)
        index(*objects)
      end

      # Queues up the remove operation for later unless a block is passed. In that case it will
      # be performed immediately.
      def remove(*objects, &block)
        if block
          # Delete by query not supported by queue, so send to server
          session.remove(*objects, &block)
        else
          objects.flatten.each do |object|
            client.remove(object)
          end
        end
      end

      # Queues up the remove operation for later unless a block is passed. In that case it will
      # be performed immediately.
      def remove!(*objects, &block)
        if block
          # Delete by query not supported by queue, so send to server
          session.remove!(*objects, &block)
        else
          remove(*objects)
        end
      end

      # Proxies remove_all to the queue session.
      def remove_all(*classes)
        # Delete by query not supported by queue, so send to server
        session.remove_all(*classes)
      end

      # Proxies remove_all! to the queue session.
      def remove_all!(*classes)
        # Delete by query not supported by queue, so send to server
        session.remove_all!(*classes)
      end

      # Queues up the index operation for later.
      def remove_by_id(clazz, id)
        client.remove(:class => clazz, :id => id)
      end

      # Queues up the index operation for later.
      def remove_by_id!(clazz, id)
        remove_by_id(clazz, id)
      end
    end
  end
end
