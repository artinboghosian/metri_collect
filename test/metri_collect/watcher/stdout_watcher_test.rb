require "test_helper"

class StdoutWatcherTest < Minitest::Test
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
    @watcher = MetriCollect::Watcher::StdoutWatcher.new(logger: @logger)
  end

  def test_watch
    watch = MetriCollect::Watch.new
    watch.namespace = 'Test'
    watch.metric_name = 'Watch'

    @watcher.watch(watch)

    assert_equal @logger.messages, ["Watching: #{watch}"]
  end
end
