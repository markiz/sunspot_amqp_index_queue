require "spec_helper"
# TODO: instead of mocking out Sunspot session, start the real search
#       server.
describe Sunspot::AmqpIndexQueue, "indexing models" do
  class TestModel
    attr_accessor :id
    def initialize(id)
      @id = id
    end

    def self.new(id)
      @models_map ||= {}
      @models_map[id] = super(id)
    end

    def self.reset_models_map
      @models_map = nil
    end

    def self.find(id)
      @models_map[id] || raise("Not found")
    end
  end

  before(:each) { TestModel.reset_models_map }

  it "adds items to queue and can process them from queue later" do
    model = TestModel.new(1)
    $session.should_receive(:index).with(model)

    Sunspot.index(model)

    $queue.status[:message_count].should == 1

    processed_count = Sunspot.session.client.process
    processed_count.should == 1

    $queue.status[:message_count].should == 0
  end

  it "removes entries when required" do
    model = TestModel.new(1)
    $session.should_receive(:remove_by_id).with("TestModel", 1)

    Sunspot.remove(model)

    $queue.status[:message_count].should == 1

    processed_count = Sunspot.session.client.process
    processed_count.should == 1

    $queue.status[:message_count].should == 0
  end

  it "readds items to queue when exceptions are raised" do
    model = TestModel.new(1)
    $session.stub(:index) { raise "Network error" }
    Sunspot.index(model)

    processed_count = Sunspot.session.client.process
    processed_count.should == 1

    $queue.status[:message_count].should == 1
    entry = Sunspot.session.client.pop
    entry.attempts_count.should == 1
    entry.run_at.should > Time.now
  end
end
