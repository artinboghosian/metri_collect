require 'log4r'

module MetriCollect
  module Publisher

    class Log4rPublisher

      def initialize(options={})
        @name = options[:name] || "metri-collect"
      end

      def publish(*metrics)
        metrics.each do |metric|
          logger.info build_message(metric) unless metric.external?
        end
      end

      def logger
        Log4r::Logger[@name]
      end

      protected

      def build_message(metric)
        message = {
          _namespace: metric.namespace,
          _metric_name: metric.name,
          _timestamp: metric.timestamp,
          _value: metric.value,
          _unit: metric.unit,
          short_message: "Published #{metric}"
        }

        metric.dimensions.each do |k,v|
          message["_dim_#{k}".to_sym] = v
        end

        message
      end
    end
  end
end