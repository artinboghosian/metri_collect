module MetriCollect
  module Publisher
    class StdoutPublisher
      def initialize(options = {})
        @logger = options[:logger] || Logger.new($stdout)
      end

      def publish(*metrics)
        metrics.each do |metric|
          @logger.info "Published: #{metric}" unless metric.external?
        end
      end
    end
  end
end
