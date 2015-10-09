require 'log4r'

module MetriCollect
  module Publisher

    class Log4rPublisher

      def initialize(options={})
        @name = options[:name] || "metri-collect"
      end

      def publish(metric)
        logger.info build_message(metric)
      end

      def logger
        Log4r::Logger[@name]
      end

      protected

      def build_message(metric)
        message = {
          :_namespace => metric.namespace,
          :_metric_name => metric.name,
          :_timestamp => metric.timestamp,
          :_value => metric.value,
          :_unit => metric.unit,
          :short_message =>
            "Published '#{metric.id}' with value '#{metric.value}'"
        }

        metric.dimensions.each do |k,v|
          message["_dim_#{k}".to_sym] = v
        end

        message
      end
    end
  end
end