require 'log4r'

module MetriCollect
  module Publisher

    class Log4rPublisher
      attr_accessor :logger

      def initialize(options={})
        @logger = options[:logger] || Log4r::Logger.new("metri-collect")
      end

      def publish(metric)
        logger.info build_message(metric)
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