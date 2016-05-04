require "metri_collect/version"
require "metri_collect/configuration"
require "metri_collect/publisher"
require "metri_collect/watcher"
require "metri_collect/watch_definition"
require "metri_collect/watch"
require "metri_collect/application"
require "metri_collect/metric_collection"
require "metri_collect/metric_definition"
require "metri_collect/metric_definition_group"
require "metri_collect/metric_template"
require "metri_collect/metric"
require "metri_collect/runner"

# publishers
require "metri_collect/publisher/test_publisher"
require "metri_collect/publisher/log4r_publisher"
require "metri_collect/publisher/cloud_watch_publisher"

# watchers
require "metri_collect/watcher/test_watcher"
require "metri_collect/watcher/cloud_watch_watcher"

module MetriCollect
  class << self
    def configure(&block)
      yield(configuration)
    end

    def [](name)
      configuration[name]
    end

    def publish(*metrics_or_ids, &block)
      configuration.default_application.publish(*metrics_or_ids, &block)
    end

    private

    def configuration
      @configuration ||= Configuration.new
    end
  end
end