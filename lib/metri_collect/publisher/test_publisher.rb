module MetriCollect
  module Publisher

    class TestPublisher
      def initialize
        @published = []
      end

      def clear
        @published.clear
      end

      def publish(metric)
        @published.push(metric)
      end

      def published?(metric)
        @published.include?(metric)
      end
    end

    add_publisher :test, TestPublisher.new
  end
end