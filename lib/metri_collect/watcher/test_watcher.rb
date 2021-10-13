
module MetriCollect
  module Watcher
    class TestWatcher
      attr_reader :watched

      def initialize
        @watched = []
      end

      def clear
        watched.clear
      end

      def watch(*watches)
        watches.each do |watch|
          watched.push(watch)
        end
      end

      def watched?(watch)
        watched.include?(watch)
      end
    end

    add_watcher :test, TestWatcher.new
  end
end
