require 'aws-sdk'

module MetriCollect
  module Watcher
    class CloudWatchWatcher
      attr_reader :options

      CLIENT_OPTS = [:region, :credentials]

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

      MISSING_MAP = {
        ok: "notBreaching",
        bad: "breaching",
        ignore: "ignore",
        missing: "missing"
      }

      def initialize(options={})
        @options = options
      end

      # CloudWatch takes care of watching the metrics
      # for us, so all we have to do is make sure that
      # the appropriate alarms exist...
      def watch(*watches)
        watches.each do |watch|
          prefixed_watch = watch.dup
          prefixed_watch.name = watch_name(watch)

          if watch_updated?(prefixed_watch)
            put_watch_as_alarm(prefixed_watch)
          end
        end
      end

      def prefix
        @prefix ||= options.fetch(:alarm_prefix, "MetriCollect - ")
      end

      def actions
        @actions ||= options.fetch(:actions, {})
      end

      def default_urgency
        options[:default_urgency]
      end

      protected

      def watch_name(watch)
        (prefix && prefix.length > 0) ? "#{prefix}#{watch.name}" : watch.name
      end

      def watch_exists?(watch)
        watches.key?(watch.name)
      end

      def watch_updated?(watch)
        !watch_exists?(watch) || watches[watch.name] != watch
      end

      def watches
        @watches ||= begin
          opts = prefix ? { alarm_name_prefix: prefix } : {}
          client.describe_alarms(opts).inject({}) do |memo, response|
            response.metric_alarms.each do |alarm|
              memo[alarm.alarm_name] = map_alarm_to_watch(alarm)
            end
            memo
          end
        end
      end

      def put_watch_as_alarm(watch)
        alarm_actions = actions.key?(watch.urgency) ? Array(actions[watch.urgency]) : nil

        begin
          response = client.put_metric_alarm({
            alarm_name: watch.name,
            alarm_description: watch.description,
            metric_name: watch.metric_name,
            namespace: watch.namespace,
            dimensions: watch.dimensions,
            period: watch.period,
            evaluation_periods: watch.evaluations,
            threshold: watch.threshold,
            statistic: statistic_symbol_to_string(watch.statistic),
            comparison_operator: comparison_symbol_to_string(watch.comparison),
            alarm_actions: alarm_actions,
            ok_actions: alarm_actions,
            insufficient_data_actions: alarm_actions,
            treat_missing_data: missing_symbol_to_string(watch.missing)
          })

          if response.successful?
            @watches[watch.name] = watch
          end

          response.successful?
        rescue Aws::CloudWatch::Errors::Throttling
          false
        end
      end

      def map_alarm_to_watch(alarm)
        Watch.from_object(
          name: alarm.alarm_name,
          description: alarm.alarm_description,
          metric_name: alarm.metric_name,
          namespace: alarm.namespace,
          evaluations: alarm.evaluation_periods,
          period: alarm.period,
          threshold: alarm.threshold,
          statistic: statistic_string_to_symbol(alarm.statistic),
          comparison: comparison_string_to_symbol(alarm.comparison_operator),
          urgency: actions_to_urgency(alarm.alarm_actions),
          missing: missing_string_to_symbol(alarm.treat_missing_data)
        )
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

      def missing_string_to_symbol(missing)
        @missing_reverse_map ||= MISSING_MAP.invert
        @missing_reverse_map.fetch(missing, :missing)
      end

      def missing_symbol_to_string(missing)
        MISSING_MAP.fetch(missing, "missing")
      end

      def actions_to_urgency(alarm_actions)
        actions.select { |urgency, action| alarm_actions.include?(action) }.keys.first || default_urgency
      end

      def client
        @client ||= Aws::CloudWatch::Client.new(options.select { |k,v| CLIENT_OPTS.include?(k) })
      end
    end
  end
end
