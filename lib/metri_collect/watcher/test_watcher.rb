
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

          puts "TestWatcher: Watching #{watch}"
        end
      end

      def watched?(watch)
        watches.include?(watch)
      end
    end

    add_watcher :test, TestWatcher.new
  end
end
