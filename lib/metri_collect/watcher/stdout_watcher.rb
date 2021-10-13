module MetriCollect
  module Watcher

    class StdoutWatcher

      def initialize(options={})
        @logger = options[:logger] || Logger.new($stdout)
      end

      def watch(*watches)
        watches.each do |watch|
          @logger.info "Watching: #{watch}"
        end
      end
    end
  end
end
