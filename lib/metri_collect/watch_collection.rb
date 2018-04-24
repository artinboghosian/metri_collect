module MetriCollect
  class WatchCollection
    include Enumerable

    attr_reader :application

    def initialize(application)
      @application = application
      @watches = {}
    end

    def each(&block)
      @watches.values.flat_map(&:values).each(&block)
    end

    def [](id)
      @watches[id].values if @watches.key?(id)
    end

    def <<(watch)
      metric_id = Metric.id(watch.metric_name, watch.namespace)
      watch_id  = watch.name

      @watches[metric_id] ||= {}

      unless @watches[metric_id].key?(watch_id)
        @watches[metric_id][watch_id] = watch
        application.watch(watch)
      end
    end
  end
end