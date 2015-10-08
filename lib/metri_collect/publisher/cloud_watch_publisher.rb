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

      def publish(metric)
        @client.put_metric_data(
          :namespace => metric.namespace,
          :metric_data => [{
            :metric_name => metric.name,
            :dimensions => metric.dimensions,
            :timestamp => metric.timestamp,
            :value => metric.value,
            :unit => unit_string(metric.unit)
          }]
        )
      end

      protected

      def unit_string(unit)
        UNITS.has_key?(unit) ? UNITS[unit] : UNITS[:none]
      end

    end
  end
end