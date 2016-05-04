require 'aws-sdk'

module MetriCollect
  module Watcher

    class CloudWatchWatcher
      STATISTIC_MAP = {
        average: "Average",
        sum: "Sum",
        maximum: "Maximum",
        minimum: "Minimum",
        sample_count: "Sample Count"
      }

      COMPARISON_MAP = {
        :> => "GreaterThanThreshold",
        :>= => "GreaterThanOrEqualToThreshold",
        :< => "LessThanThreshold",
        :<= => "LessThanOrEqualToThreshold"
      }

      def initialize(options={})
        @prefix = options.delete(:alarm_prefix) || "MetriCollect - "
        @client = Aws::CloudWatch::Client.new(options)
      end

      # CloudWatch takes care of watching the metrics
      # for us, so all we have to do is make sure that
      # the appropriate alarms exist...
      def watch(*metrics)
        metrics.each do |metric|
          metric.watches.each do |watch|
            prefixed_watch = watch.dup
            prefixed_watch.name = watch_name(watch)

            if watch_updated?(prefixed_watch)
              put_watch_as_alarm(prefixed_watch, metric)
            end
          end
        end
      end

      protected

      def watch_name(watch)
        (@prefix && @prefix.length > 0) ? "#{@prefix}#{watch.name}" : watch.name
      end

      def watch_exists?(watch)
        watches.key?(watch.name)
      end

      def watch_updated?(watch)
        !watch_exists?(watch) || watches[watch.name] != watch
      end

      def watches
        @watches ||= begin
          @client.describe_alarms(alarm_name_prefix: @prefix).inject({}) do |hash, response|
            response.metric_alarms.each do |alarm|
              hash[alarm.alarm_name] = map_alarm_to_watch(alarm)
            end
            hash
          end
        end
      end

      def put_watch_as_alarm(watch, metric)
        response = @client.put_metric_alarm({
          alarm_name: watch.name,
          alarm_description: watch.description,
          metric_name: metric.name,
          namespace: metric.namespace,
          dimensions: metric.dimensions,
          period: watch.period,
          evaluation_periods: watch.evaluations,
          threshold: watch.threshold,
          statistic: statistic_symbol_to_string(watch.statistic),
          comparison_operator: comparison_symbol_to_string(watch.comparison)
        })

        if response.successful?
          @watches[watch.name] = watch
        end

        response.successful?
      end

      def map_alarm_to_watch(alarm)
        Watch.from_object({
          name: alarm.alarm_name,
          description: alarm.alarm_description,
          evaluations: alarm.evaluation_periods,
          period: alarm.period,
          threshold: alarm.threshold,
          statistic: statistic_string_to_symbol(alarm.statistic),
          comparison: comparison_string_to_symbol(alarm.comparison_operator)
        })
      end

      def statistic_string_to_symbol(statistic)
        @statistic_reverse_map ||= STATISTIC_MAP.invert
        @statistic_reverse_map[statistic] || raise(ArgumentError, "Unable to convert '#{statistic}' into watch statistic")
      end

      def statistic_symbol_to_string(statistic)
        STATISTIC_MAP[statistic] || raise(ArgumentError, "Unable to convert '#{statistic}' into watch statistic")
      end

      def comparison_string_to_symbol(comparison)
        @comparison_reverse_map ||= COMPARISON_MAP.invert
        @comparison_reverse_map[comparison] || raise(ArgumentError, "Unable to convert '#{comparison}' into watch comparison")
      end

      def comparison_symbol_to_string(comparison)
        COMPARISON_MAP[comparison] || raise(ArgumentError, "Unable to convert '#{comparison}' into watch comparison")
      end
    end
  end
end
