require 'aws-sdk'

module MetriCollect
  module Publisher

    class CloudWatchPublisher

      UNITS = {
         :seconds => "Seconds",
         :microseconds => "Microseconds",
         :bytes => "Bytes",
         :kilobytes => "Kilobytes",
         :megabytes => "Megabytes",
         :gigabytes => "Gigabytes",
         :terabytes => "Terabytes",
         :bits => "Bits",
         :kilobits => "Kilobits",
         :megabits => "Megabits",
         :gigabits => "Gigabits",
         :terabits => "Terabits",
         :percent => "Percent",
         :count => "Count",
         :bytes_per_second => "Bytes/Second",
         :kilobytes_per_second => "Kilobytes/Second",
         :megabytes_per_second => "Megabytes/Second",
         :gigabytes_per_second => "Gigabytes/Second",
         :terabytes_per_second => "Terabytes/Second",
         :bits_per_second => "Bits/Second",
         :kilobits_per_second => "Kilobits/Second",
         :megabits_per_second => "Megabits/Second",
         :gigabits_per_second => "Gigabits/Second",
         :terabits_per_second => "Terabits/Second",
         :count_per_second => "Count/Second",
         :none => "None"
      }

      def initialize(options={})
        @client = Aws::CloudWatch::Client.new(options)
      end

      def publish(*metrics)
        # group metrics by namespace
        namespaces = {}
        metrics.each do |obj|
          metric = Metric.from_object(obj)
          namespaces[metric.namespace] ||= []
          namespaces[metric.namespace] << metric
        end

        # publish each namespace...
        namespaces.each do |namespace, metrics_array|
          puts "Pushing namespace: #{namespace} (has #{metrics_array.size} metrics)"
          @client.put_metric_data(
            :namespace => namespace,
            :metric_data => metrics_array.map do |metric|
              {
                :metric_name => metric.name,
                :dimensions => metric.dimensions,
                :timestamp => metric.timestamp,
                :value => metric.value,
                :unit => unit_string(metric.unit)
              }
            end
          )
        end
      end

      protected

      def unit_string(unit)
        UNITS.has_key?(unit) ? UNITS[unit] : UNITS[:none]
      end

    end
  end
end