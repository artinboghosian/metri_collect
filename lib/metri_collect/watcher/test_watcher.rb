require 'aws-sdk'

module MetriCollect
  module Watcher

    class TestWatcher
      def initialize(options={})
        @options = options
        @metrics = {}
        @watches = {}
        @results = {}
      end

      def watch(*metrics)
        updated = metrics.map(&:name).uniq

        metrics.each do |metric|
          add_metric(metric)
          set_watches(metric)
        end

        check_watches(updated)
      end

      def status(watch_name)
        @results[watch_name]
      end

      protected

      def check_watches(metric_names)
        metric_names.each do |metric_name|
          watches(metric_name).each do |watch|
            check_watch(metric_name, watch)
          end
        end
      end

      def check_watch(metric_name, watch)
        now = Time.now.to_i
        next_period = now + (watch.period - (now.to_i % watch.period))
        status = :triggered

        log "Beginning check_watch for '#{metric_name}': #{watch}..."

        evals = (watch.evaluations + 1).times.map do |eval_num|
          range_start = Time.at(next_period - watch.period)
          range_end = Time.at(next_period)
          next_period = range_start.to_i

          items = metrics(metric_name).select {|m| m.timestamp >= range_start && m.timestamp < range_end}.map(&:value)
          stat = if items.count > 0
            case watch.statistic
              when items.count == 0; nil
              when :sum; items.inject(0.0) {|s,x| s + x}
              when :average; items.inject(0.0) {|s,x| s + x} / items.count.to_f
              when :minimum; items.min
              when :maximum; items.max
              when :sample_count; items.count
              else raise "Unknown statistic '#{watch.statistic}'"
            end
          else
            nil
          end

          result = if stat.nil?
            :insufficient_data
          elsif stat.send(watch.comparison, watch.threshold)
            :triggered
          else
            :ok
          end

          log "  Checking watch '#{watch}':"
          log "    Period range:    #{Time.at(range_start)}..#{Time.at(range_end)}"
          log "    Samples:         [#{items.join(',')}]"
          log "    Sample count:    #{items.count}"
          log "    Statistic value: #{stat}"
          log "    Result:          #{result}"

          result
        end

        # we can leave the last entry out if it
        # doesn't have any data yet...
        evals.pop if evals.last == :insufficient_data

        ok_count, insuf_count = evals.inject([0,0]) do |x,item|
          [
            x[0] + (item == :ok ? 1 : 0),
            x[1] + (item == :insufficient_data ? 1 : 0)
          ]
        end

        status = :ok if ok_count > 0
        status = :insufficient_data if insuf_count > 0

        log "Evaluation results: #{evals}"
        log "Overall result: #{status}"

        @results[watch.name] = status

        status
      end

      def metrics(metric_name)
        @metrics[metric_name] || []
      end

      def watches(metric_name)
        @watches[metric_name] || []
      end

      def add_metric(metric)
        @metrics[metric.name] ||= []
        @metrics[metric.name] << metric

        if @min_timestamp.nil? || @min_timestamp > metric.timestamp
          @min_timestamp = metric.timestamp
        end

        if @max_timestamp.nil? || @max_timestamp < metric.timestamp
          @max_timestamp = metric.timestamp
        end
      end

      def set_watches(metric)
        @watches[metric.name] = metric.watches || []
      end

      def log(message)
        puts message if verbose?
      end

      def verbose?
        @options[:verbose]
      end
    end

    add_watcher :test, TestWatcher.new
  end
end
