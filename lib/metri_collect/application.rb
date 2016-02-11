module MetriCollect
  class Application
    attr_reader :name

    def initialize(name)
      raise ArgumentError, "Application name must not be empty" if name.nil? || name.length < 1

      @name = name
      @namespace_prefix = nil
      @publishers = []
    end

    def prefix_namespace_with(prefix)
      @namespace_prefix = prefix
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
          metric.namespace = "#{namespace_prefix}/#{metric.namespace}" if namespace_prefix
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
      namespace_prefix ? "#{namespace_prefix}/#{name}" : name
    end

    def namespace_prefix
      @namespace_prefix
    end
  end
end