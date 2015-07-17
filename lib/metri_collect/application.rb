module MetriCollect
  class Application
    attr_accessor :publisher
    attr_reader   :name

    def initialize(name)
      @name = name
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