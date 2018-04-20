module MetriCollect
  class WatchCollection
    include Enumerable

    attr_reader :application

    def initialize(application)
      @application = application
      @watches = {}
    end

    def each(&block)
      @watches.values.flatten.each(&block)
    end

    def [](id)
      @watches[id]
    end

    def <<(watch)
      id = Metric.id(watch.metric_name, watch.namespace)

      @watches[id] ||= []
      @watches[id] << watch
    end

    private

    def watch_defined?(id)
      @watches.key?(id)
    end
  end
end