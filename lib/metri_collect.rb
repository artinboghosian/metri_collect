require "metri_collect/version"
require "metri_collect/configuration"
require "metri_collect/publisher"
require "metri_collect/application"
require "metri_collect/metric_collection"
require "metri_collect/metric_definition"
require "metri_collect/metric"

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