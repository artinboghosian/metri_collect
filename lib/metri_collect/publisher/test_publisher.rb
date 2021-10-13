module MetriCollect
  module Publisher
    class TestPublisher
      attr_reader :published

      def initialize
        @published = []
      end

      def clear
        published.clear
      end

      def publish(*metrics)
        metrics.each do |metric|
          published.push(metric) unless metric.external?
        end
      end

      def published?(metric)
        published.include?(metric)
      end
    end

    add_publisher :test, TestPublisher.new
  end
end
