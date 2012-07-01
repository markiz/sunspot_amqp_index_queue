# AMQP Index Queue for sunspot

Asynchronously index your sunspot models.

## Rationale and influences

This library is heavily influenced by [https://github.com/bdurand/sunspot_index_queue](sunspot_index_queue) gem. My motivation to write a separate library instead of an adapter was mainly to remove features that were difficult to implement in an AMQP queue terms (keeping failed jobs and error messages, priorities). However, one "weird" feature, namely, retrying jobs after a certain period on failure, made its way through.

## Installation

Add this line to your application's Gemfile:

    gem 'sunspot_amqp_index_queue'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sunspot_amqp_index_queue

## Usage

There are two parts to asynchronous indexer, first is a proxy that sends
all index/remove requests to a queue:


    # Somewhere in an initializer (for Rails) / before your code starts
    require 'sunspot_amqp_index_queue'
    amqp_config = {
      "host"       => "localhost",
      "port"       => 5672,
      "user"       => "guest",
      "pass"       => "guest",
      "vhost"      => "/",
      "queue_name" => "indexer_queue"
    }
    # Implies that Sunspot.session is already initialized as your real sunspot
    # session
    Sunspot.session = Sunspot::AmqpIndexQueue::SessionProxy.new(Sunspot.session, amqp_config)


Second part is an indexing daemon that handles processing. It boils down to


    # ... require environment

    loop do
      Sunspot.session.client.process(20) # process 20 entries
      sleep(1)
    end

## Thread-safety

It is safe to use a threaded solution for an indexer, separate connection to
AMQP broker will be made per-thread. It is also safe to instantiate more than
one Sunspot::AmqpIndexQueue::SessionProxy or Sunspot::AmqpIndexQueue::Client
in one thread.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

This library is in [public domain](http://unlicense.org/UNLICENSE).
