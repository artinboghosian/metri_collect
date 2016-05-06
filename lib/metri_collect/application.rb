module MetriCollect
  class Application
    attr_reader :name

    def initialize(name)
      raise ArgumentError, "Application name must not be empty" if name.nil? || name.length < 1

      @name = name
      @metric_prefix = nil
      @publishers = []
      @watchers = []
    end

    def prefix_metrics_with(prefix)
      @metric_prefix = prefix
    end

    def publishers(*keys_or_publishers)
      keys_or_publishers.each do |key_or_publisher|
        add_publisher(key_or_publisher)
      end
    end

    def add_publisher(key_or_publisher)
      @publishers << if key_or_publisher.is_a?(Symbol)
        Publisher[key_or_publisher] || raise(ArgumentError, "publisher doesn't exist: #{key_or_publisher}")
      else
        key_or_publisher
      end
    end

    def watchers(*keys_or_watchers)
      keys_or_watchers.each do |key_or_watcher|
        add_watcher(key_or_watcher)
      end
    end

    def add_watcher(key_or_watcher)
      @watchers << if key_or_watcher.is_a?(Symbol)
        Watcher[key_or_watcher] || raise(ArgumentError, "watcher doesn't exist: #{key_or_watcher}")
      else
        key_or_watcher
      end
    end

    def metrics(&block)
      raise RuntimeError, "metrics have not been configured" unless block_given? || @metrics

      if block_given?
        @metrics = MetricCollection.new(namespace)
        @metrics.instance_eval(&block)
      else
        @metrics
      end
    end

    def metric_ids(roles = [])
      metrics.ids(roles)
    end

    def publish(*metrics_or_ids, &block)
      metrics_or_ids << MetricDefinition.new(nil, nil, &block).call if block_given?
      metrics = convert_to_metric(*metrics_or_ids)

      @publishers.each do |publisher|
        publisher.publish(*metrics)
      end

      @watchers.each do |watcher|
        watcher.watch(*metrics)
      end
    end

    def publish_all
      metrics.each do |metric|
        publish(metric)
      end
    end

    private

    def namespace
      metric_prefix ? "#{name}/#{metric_prefix}" : name
    end

    def metric_prefix
      @metric_prefix
    end

    def convert_to_metric(*metrics_or_ids)
      metrics_or_ids.flat_map do |metric_or_id|
        case metric_or_id
        when Array
          convert_to_metric(*metric_or_id)
        when String
          metrics[metric_or_id]
        else
          metric = MetricDefinition.build_metric(metric_or_id)
          metric.namespace = metric.namespace.split("/").insert(1, metric_prefix).join("/") if metric_prefix
          metric
        end
      end
    end
  end
end