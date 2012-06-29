require "spec_helper"

describe Sunspot::AmqpIndexQueue::Client do
  describe "initialization" do
    it "sets up a queue if it doesn't exist" do
      subject = nil
      described_class.new($session, $amqp_config.merge("sunspot_index_queue_name" => "shakalaka"))
      queue = $bunny.queue("shakalaka", "passive" => true)
      queue.should_not be_blank
      queue.delete
    end
  end
end
