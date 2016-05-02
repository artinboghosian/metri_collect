
module MetriCollect
  module Watcher
    class << self
      def [](key)
        watchers[key]
      end

      def add_watcher(key, watcher)
        watchers[key] = watcher
      end

      private

      def watchers
        @watchers ||= {}
      end
    end
  end
end
