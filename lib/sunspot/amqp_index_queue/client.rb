require 'active_support/core_ext/hash'
require 'bunny'

module Sunspot
  module AmqpIndexQueue
    class Client
      MAX_ATTEMPTS_COUNT = 5
      REINDEX_PERIOD = 300
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

      attr_reader :session, :bunny

      # Instantiate a new client session
      # @param [Sunspot::Session] session sunspot session that receive the
      #     requests during processing
      # @param [Hash] client_opts options for bunny client
      # @api public
      def initialize(session, client_opts = {})
        @session = session
        @options = default_options.merge(client_opts)
        @bunny   = Bunny.new(@options.slice(:user, :pass, :host, :port, :vhost))
        @bunny.start
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
        while i < limit && entry = pop_next_available
          process_entry(entry)
          i += 1
        end
        i
      end

      def process_entry(entry)
        if entry.attempts_count < MAX_ATTEMPTS_COUNT
          if entry.to_remove
            session.remove_by_id(entry.object_class_name, entry.object_id)
          else
            session.index(entry.object)
          end
        end
      rescue => e
        if defined?(Rails)
          Rails.logger.error "Exception raised while indexing: #{e.class}: #{e}"
        end
        entry.run_at = REINDEX_PERIOD.since
        entry.attempts_count += 1
        push(entry)
      end

      def push(entry)
        exchange.publish(Marshal.dump(entry), :key => queue_name)
      end

      def pop
        entry = queue.pop[:payload]
        if (entry != :queue_empty)
          Marshal.load(entry)
        else
          nil
        end
      end

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

      protected

      def default_options
        HashWithIndifferentAccess.new({
          :queue_name => "sunspot_index_queue",
          :user => "guest",
          :pass => "guest",
          :host => "localhost",
          :port => "5672",
          :vhost => "/"
        })
      end

      def queue_name
        @options[:queue_name]
      end

      def queue
        @queue ||= bunny.queue(queue_name, :passive => true, :durable => true)
      end

      def exchange
        @exchange ||= bunny.exchange('')
      end

      def new_entry_for_object(object, extra_attributes = {})
        entry = Entry.new({
          :object_id         => object.id,
          :object_class_name => object.class.name
        }.merge(extra_attributes))
      end
    end
  end
end
