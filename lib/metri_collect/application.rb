module MetriCollect
  class Application
    attr_reader :name, :publisher

    def initialize(name)
      @name = name
    end

    def publisher=(key_or_publisher)
      @publisher = if key_or_publisher.is_a?(Symbol)
        Publisher[key_or_publisher] || raise(ArgumentError, "publisher doesn't exist: #{key_or_publisher}")
      else
        key_or_publisher
      end
    end

    def metrics(&block)
      raise RuntimeError, "metrics have not been configured" unless block_given? || @metrics

      if block_given?
        @metrics = MetricCollection.new(name)
        @metrics.instance_eval(&block)
      else
        @metrics
      end
    end

    def publish(metric)
      publisher.publish(metric)
    end

    def publish_all
      metrics.each do |metric|
        publish(metric)
      end
    end
  end
end