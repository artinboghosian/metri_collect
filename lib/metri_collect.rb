require "metri_collect/version"
require "metri_collect/configuration"
require "metri_collect/publisher"
require "metri_collect/application"
require "metri_collect/metric_collection"
require "metri_collect/metric_definition"
require "metri_collect/metric"

# publishers
require "metri_collect/publisher/test_publisher"
require "metri_collect/publisher/log4r_publisher"
require "metri_collect/publisher/cloud_watch_publisher"

module MetriCollect
  class << self
    def configure(&block)
      yield(configuration)
    end

    def [](name)
      configuration[name]
    end

    private

    def configuration
      @configuration ||= Configuration.new
    end
  end
end