module MetriCollect
  class Application
    attr_reader :name

    def initialize(name)
      raise ArgumentError, "Application name must not be empty" if name.nil? || name.length < 1

      @name = name
      @metric_prefix = nil
      @publishers = []
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

    def metrics(&block)
      raise RuntimeError, "metrics have not been configured" unless block_given? || @metrics

      if block_given?
        @metrics = MetricCollection.new(namespace)
        @metrics.instance_eval(&block)
      else
        @metrics
      end
    end

    def publish(*metrics_or_ids)
      metrics = metrics_or_ids.map do |metric_or_id|
        case metric_or_id
        when String
          self.metrics[metric_or_id]
        else
          metric = Metric.from_object(metric_or_id)
          metric.namespace = metric.namespace.split("/").insert(1, metric_prefix).join("/") if metric_prefix
          metric
        end
      end

      @publishers.each do |publisher|
        publisher.publish(*metrics)
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
  end
end