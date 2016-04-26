module MetriCollect
  class MetricCollection
    include Enumerable

    def initialize(namespace)
      @namespaces         = [namespace]
      @metric_definitions = {}
    end

    def namespace(namespace, &block)
      @namespaces.push(namespace)
      yield
      @namespaces.pop
    end

    def group(name, &block)
      id = Metric.id(name, current_namespace)

      if metric_defined?(id)
        raise ArgumentError, "Metric '#{id}' has already been defined"
      else
        @metric_definitions[id] = MetricDefinitionGroup.new(name, current_namespace, &block)
      end
    end

    def metric(name, &block)
      group(name) { metric(&block) }
    end

    def each(&block)
      @metric_definitions.values.flat_map(&:call).each(&block)
    end

    def ids
      @metric_definitions.keys
    end

    def [](id)
      raise ArgumentError, "Metric '#{id}' has not been defined" unless metric_defined?(id)
      @metric_definitions[id].call
    end

    private

    def current_namespace
      @namespaces.join("/")
    end

    def metric_defined?(id)
      @metric_definitions.key?(id)
    end
  end
end