require 'aws-sdk'

module MetriCollect
  module Watcher
    class CloudWatchWatcher
      attr_reader :options

      STATISTIC_MAP = {
        average: "Average",
        sum: "Sum",
        maximum: "Maximum",
        minimum: "Minimum",
        sample_count: "Sample Count",
        other: "Other"
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

          if watch_needs_update?(prefixed_watch)
            put_watch_as_alarm(prefixed_watch)
          end
        end
      end

      def prefix
        @prefix ||= options.fetch(:alarm_prefix, "MetriCollect - ")
      end

      def urgency_actions
        @urgency_actions ||= options.fetch(:urgency_actions, {}).inject({}) do |memo, (key, value)|
          memo.update(key => Array(value))
        end
      end

      def default_actions
        @default_actions ||= {
          stop:      { alarm: "arn:aws:automate:#{region}:ec2:stop" },
          terminate: { alarm: "arn:aws:automate:#{region}:ec2:terminate" },
          recover:   { alarm: "arn:aws:automate:#{region}:ec2:recover" }
        }
      end

      def actions
        @actions ||= begin
          default_actions.merge(options.fetch(:actions, {})).inject({}) do |memo, (key, value)|
            value = { ok: Array(value), insufficient_data: Array(value), alarm: Array(value) } unless value.is_a?(Hash)
            value.each { |k,v| value.update(k => Array(v)) }
            memo.update(key => value)
          end
        end
      end

      def grace_period
        @grace_period ||= options.fetch(:grace_period, 0)
      end

      def default_urgency
        options[:default_urgency]
      end

      protected

      def watch_name(watch)
        (prefix && prefix.length > 0) ? "#{prefix}#{watch.name}" : watch.name
      end

      def watch_needs_update?(watch)
        return true unless watches.key?(watch.name)

        watch_info   = watches[watch.name]
        stored_watch = watch_info[:watch]
        updated_at   = watch_info[:updated_at]

        return false if stored_watch == watch

        Time.now > (updated_at + grace_period)
      end

      def watches
        @watches ||= begin
          opts = prefix ? { alarm_name_prefix: prefix } : {}
          client.describe_alarms(opts).inject({}) do |memo, response|
            response.metric_alarms.each do |alarm|
              memo[alarm.alarm_name] = {
                watch: map_alarm_to_watch(alarm),
                updated_at: alarm.alarm_configuration_updated_timestamp
              }
            end
            memo
          end
        end
      end

      def put_watch_as_alarm(watch)
        urgency    = watch.urgency || default_urgency
        action_map = actions_for_watch(watch)
        attempts   = 0

        begin
          response = client.put_metric_alarm(
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
            alarm_actions: action_map[:alarm],
            ok_actions: action_map[:ok],
            insufficient_data_actions: action_map[:insufficient_data],
            treat_missing_data: missing_symbol_to_string(watch.missing)
          )

          if response.successful?
            @watches[watch.name] = {
              watch: watch,
              updated_at: Time.now
            }
          end

          response.successful?
        rescue Aws::CloudWatch::Errors::Throttling
          return false if attempts > 3
          attempts += 1
          sleep (attempts * 5)
          retry
        end
      end

      def map_alarm_to_watch(alarm)
        action_keys  = alarm_action_keys(alarm)
        urgency      = action_keys_to_urgency(action_keys)
        action_keys -= urgency_actions[urgency] if urgency

        Watch.from_object(
          name: alarm.alarm_name,
          description: alarm.alarm_description,
          metric_name: alarm.metric_name,
          namespace: alarm.namespace,
          dimensions: alarm.dimensions.inject([]) { |m,d| m << { name: d.name, value: d.value } },
          evaluations: alarm.evaluation_periods,
          period: alarm.period,
          threshold: alarm.threshold,
          statistic: statistic_string_to_symbol(alarm.statistic),
          comparison: comparison_string_to_symbol(alarm.comparison_operator),
          missing: missing_string_to_symbol(alarm.treat_missing_data),
          urgency: urgency,
          actions: action_keys
        )
      end

      def actions_for_watch(watch)
        urgency     = watch.urgency || default_urgency
        action_keys = watch.actions + urgency_actions[urgency]
        actions_map = action_keys.inject({ ok: [], insufficient_data: [], alarm: [] }) do |memo, key|
          actions.fetch(key, {}).each { |k, v| memo[k] += v if memo.key?(k) } if value = [key]
          memo
        end
      end

      def statistic_string_to_symbol(statistic)
        @statistic_reverse_map ||= STATISTIC_MAP.invert
        @statistic_reverse_map[statistic] || :other
      end

      def statistic_symbol_to_string(statistic)
        STATISTIC_MAP[statistic] || "Other"
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

      def action_keys_to_urgency(action_keys)
        urgency_actions.select do |urgency, keys|
          action_keys & keys == keys
        end.keys.first
      end

      def alarm_action_keys(alarm)
        actions.select do |key, value|
          (value[:alarm].nil? || alarm.alarm_actions & value[:alarm] == value[:alarm]) &&
          (value[:insufficient_data].nil? || alarm.insufficient_data_actions & value[:insufficient_data] == value[:insufficient_data]) &&
          (value[:ok].nil? || alarm.ok_actions & value[:ok] == value[:ok])
        end.keys
      end

      def region
        options.fetch(:region, "us-west-1")
      end

      def credentials
        options[:credentials]
      end

      def client
        @client ||= Aws::CloudWatch::Client.new(region: region, credentials: credentials)
      end
    end
  end
end
