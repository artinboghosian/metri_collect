module MetriCollect
  module Publisher
    class << self
      def [](key)
        publishers[key]
      end

      def add_publisher(key, publisher)
        publishers[key] = publisher
      end

      private

      def publishers
        @publishers ||= {}
      end
    end

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
