require 'log4r'

module MetriCollect
  module Watcher

    class Log4rWatcher

      def initialize(options={})
        @name = options[:name] || "metri-collect"
      end

      def watch(*watches)
        watches.each do |watch|
          logger.info build_message(watch)
        end
      end

      def logger
        Log4r::Logger[@name]
      end

      protected

      def build_message(watch)
        message = {
          _watch_name: watch.name,
          _description: watch.description,
          _namespace: watch.namespace,
          _metric_name: watch.metric_name,
          _statistic: watch.statistic,
          _period: watch.period,
          _comparison: watch.comparison,
          _threshold: watch.threshold,
          _urgency: watch.urgency,
          _missing: watch.missing,
          _actions: watch.actions,
          short_message: "Watching #{watch}"
        }

        watch.dimensions.each do |k,v|
          message["_dim_#{k}".to_sym] = v
        end

        message
      end
    end
  end
end