module MetriCollect
  class Application
    attr_reader :name

    def initialize(name)
      raise ArgumentError, "Application name must not be empty" if name.nil? || name.length < 1
      @name = name
    end

    def publishers(*keys_or_publishers)
      @publishers = keys_or_publishers.map do |key_or_publisher|
        if key_or_publisher.is_a?(Symbol)
          Publisher[key_or_publisher] || raise(ArgumentError, "publisher doesn't exist: #{key_or_publisher}")
        else
          key_or_publisher
        end
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
      @publishers.each do |publisher|
        publisher.publish(metric)
      end
    end

    def publish_all
      metrics.each do |metric|
        publish(metric)
      end
    end
  end
end