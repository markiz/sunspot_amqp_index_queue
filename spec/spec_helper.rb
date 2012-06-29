require "rspec"
require "rspec/core"
require "rspec/mocks"
require "rspec/autorun"
require "sunspot"
require "sunspot_amqp_index_queue"
require "yaml"

RSpec.configure do |c|
  c.mock_with :rspec
  c.before(:all) do
    $amqp_config = HashWithIndifferentAccess.new(YAML.load(File.read("spec/amqp.yml")))
    $bunny = Bunny.new($amqp_config)
    $bunny.start
    $queue = $bunny.queue($amqp_config["sunspot_index_queue_name"], :durable => true)
  end

  c.before(:each) do
    $session = stub(:sunspot_session).as_null_object
    Sunspot.session = Sunspot::AmqpIndexQueue::SessionProxy.new($session, $amqp_config)
    $queue.purge
  end
end
