require "test_helper"

class StdoutPublisherTest < Minitest::Test
  class MockLogger
    def info(message)
      messages << message
    end

    def messages
      @messages ||= []
    end
  end

  def setup
    @logger = MockLogger.new
    @publisher = MetriCollect::Publisher::StdoutPublisher.new(logger: @logger)
  end

  def test_publish
    metric = MetriCollect::Metric.new
    metric.namespace = 'Test'
    metric.name = 'Info'
    metric.value = 1

    @publisher.publish(metric)

    assert_equal @logger.messages, ["Published: #{metric}"]
  end
end
