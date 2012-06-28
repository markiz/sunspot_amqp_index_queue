# SunspotAmqpIndexQueue

Asynchronously index your sunspot models.


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

```
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
```

Second part is an indexing daemon that handles processing. It boils down to

```
# ... require environment

loop do
  Sunspot.session.client.process(20) # process 20 entries
  sleep(1)
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
