module MetriCollect
  class MetricTemplate
    class << self
      def [](key)
        templates[key]
      end

      def add_template(key, &body)
        templates[key] = new(key, &body)
      end

      private

      def templates
        @templates ||= {}
      end
    end

    def initialize(name, &body)
      @name = name
      @body = body
    end

    def apply(context, &block)
      context.instance_eval(&block)
      context.instance_eval(&@body)
    end
  end
end