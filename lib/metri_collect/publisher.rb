
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
  end
end
