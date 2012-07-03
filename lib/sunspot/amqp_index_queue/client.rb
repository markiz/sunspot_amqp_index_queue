require 'active_support/core_ext/hash'
require 'bunny'

module Sunspot
  module AmqpIndexQueue
    # Wrapper around AMQP queue. Provides several useful public API methods,
    # such as {#count} and {#process}.
    class Client
      # Wrapper around entry in an indexer queue
      # @private
      class Entry
        ATTRIBUTES = [
          :object_id, :object_class_name, :to_remove,
          :attempts_count, :run_at
        ].freeze

        def initialize(attributes = {})
          @attributes = default_attributes.merge(attributes.slice(*ATTRIBUTES))
        end

        def default_attributes
          HashWithIndifferentAccess.new({
            :to_remove      => false,
            :attempts_count => 0,
            :run_at         => Time.now
          })
        end

        def object
          @object ||= object_class_name.constantize.find(object_id)
        end

        def attributes
          @attributes
        end

        def marshal_dump
          @attributes
        end

        def marshal_load(attributes)
          @attributes = attributes
        end

        ATTRIBUTES.each {|k| define_method(k) { attributes[k] } }
        ATTRIBUTES.each {|k| define_method("#{k}=") {|v| attributes[k] = v } }

      end

      attr_reader :session

      # Instantiate a new client session
      # @param [Sunspot::Session] session sunspot session that receive the
      #     requests during processing
      # @option client_opts [String] "host" ("localhost") AMQP host name
      # @option client_opts [Integer] "port" (55672) AMQP port
      # @option client_opts [String] "user" ("guest") AMQP user name
      # @option client_opts [String] "pass" ("guest") AMQP password
      # @option client_opts [String] "vhost" ("/") AMQP vhost
      # @option client_opts [String] "sunspot_index_queue_name" ("sunspot_index_queue")
      #    AMQP index queue name
      # @option client_opts [Integer] "retry_interval" (300) time before next
      #    indexing attempt in case of failure / exception
      # @option client_opts [Integer] "max_attempts_count" (5) attempts count
      # @option client_opts [Integer] "index_delay" (0) delay in seconds between receiving
      #    a message about indexing and trying to process it
      # @api public
      def initialize(session, client_opts = {})
        @session = session
        @options = default_options.merge(client_opts)
        prepare_queue_and_exchange
      end

      # @return [Integer] Number of pending jobs in the queue
      # @api public
      def count
        queue.status[:message_count]
      end

      # Send an object into queue for indexing
      # @param [Object] object item to process
      # @api public
      def index(object)
        push(new_entry_for_object(object))
      end

      # Send an object into queue for removing from index
      # @param [Object] object item to process
      # @api public
      def remove(object)
        push(new_entry_for_object(object, :to_remove => true))
      end

      # Index or remove several entries from the queue.
      # @param [Integer] limit maximum number of entries to process
      # @return [Integer] number of entries processed
      # @api public
      def process(limit = 10)
        i = 0
        while i < limit && (entry = pop_next_available)
          process_entry(entry)
          i += 1
        end
        i
      end

      # Push an entry into the queue
      # @api semipublic
      def push(entry)
        exchange.publish(Marshal.dump(entry), :key => queue_name)
      end

      # Pops an entry from the queue
      # @api semipublic
      def pop
        entry = queue.pop[:payload]
        if (entry != :queue_empty)
          Marshal.load(entry)
        else
          nil
        end
      end

      protected

      # List of default options ofr a client
      # @api semipublic
      def default_options
        HashWithIndifferentAccess.new({
          :sunspot_index_queue_name => "sunspot_index_queue",
          :user => "guest",
          :pass => "guest",
          :host => "localhost",
          :port => "5672",
          :vhost => "/",
          :max_attempts_count => 5,
          :retry_interval     => 300,
          :index_delay        => 0
        })
      end
      # Number of failures allowed before being dropped from an index
      # queue altogether
      # @api semipublic
      def max_attempts_count
        @options[:max_attempts_count]
      end

      # Interval in seconds before reindex is attempted after a failure.
      # @api semipublic
      def retry_interval
        @options[:retry_interval]
      end

      # Current bunny session.
      # @api semipublic
      def bunny
        Thread.current["#{object_id}_bunny"] ||= init_bunny
      end

      # Index queue name
      # @api semipublic
      def queue_name
        @options[:sunspot_index_queue_name] || @options[:queue_name]
      end

      # Bunny index queue
      # @api semipublic
      def queue
        Thread.current["#{object_id}_queue"] ||= bunny.queue(queue_name, :durable => true)
      end

      # Bunny exchange
      # @api semipublic
      def exchange
        Thread.current["#{object_id}_exchange"] ||= bunny.exchange('')
      end

      def index_delay
        @options[:index_delay]
      end

      # Gets a next available (with run_at < Time.now) entry out of the
      # queue. All the skipped entries are then pushed back into the queue.
      # @api semipublic
      def pop_next_available
        unused_entries = []
        result = nil
        while (entry = pop)
          if entry.run_at <= Time.now
            result = entry
            break
          else
            unused_entries << entry
          end
        end
        unused_entries.each {|e| push(e) }
        result
      end


      # Index or remove an entry
      # @api semipublic
      def process_entry(entry)
        if entry.attempts_count < max_attempts_count
          if entry.to_remove
            session.remove_by_id(entry.object_class_name, entry.object_id)
          else
            session.index(entry.object)
          end
        end
      rescue => e
        if defined?(::Rails)
          ::Rails.logger.error "Exception raised while indexing: #{e.class}: #{e}"
        end
        entry.run_at = Time.now + retry_interval
        entry.attempts_count += 1
        push(entry)
      end

      # @api private
      def new_entry_for_object(object, extra_attributes = {})
        Entry.new({
          :object_id         => object.id,
          :object_class_name => object.class.name,
          :run_at            => Time.now + index_delay
        }.merge(extra_attributes))
      end

      # @api private
      def init_bunny
        bunny = Bunny.new(@options.slice(:user, :pass, :host, :port, :vhost))
        bunny.start
        bunny
      end

      # @api private
      def prepare_queue_and_exchange
        # trigger lazily evaluated initialization
        queue
        exchange
      end
    end
  end
end
