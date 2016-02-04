module MetriCollect
  module Publisher

    class TestPublisher
      def initialize
        @published = []
      end

      def clear
        @published.clear
      end

      def publish(*metrics)
        metrics.each do |metric|
          metric_obj = Metric.from_object(metric)
          @published.push(metric_obj)
          puts "TestPublisher: Published #{metric}"
        end
      end

      def published?(metric)
        @published.include?(metric)
      end
    end

    add_publisher :test, TestPublisher.new
  end
end