module MetriCollect
  class Application
    attr_reader :name, :publisher

    def initialize(name)
      @name = name
    end

    def publisher=(key_or_publisher)
      @publisher = if key_or_publisher.is_a?(Symbol)
        if Publisher[key_or_publisher]
          Publisher[key_or_publisher]
        else
          raise ArgumentError, "no publisher found for key #{key_or_publisher}. Did you call #add_publisher in configuration?"
        end
      else
      end
    end

    def metrics(&block)
      raise RuntimeError, "metrics have not been configured" unless block_given? || @metrics

      if block_given?
        @metrics = MetricCollection.new(self)
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