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

    def metric(name, &block)
      id = Metric.id(name, current_namespace)
      raise ArgumentError, "Metric '#{id}' has already been defined" if metric_defined?(id)
      @metric_definitions[id] = MetricDefinition.new(name, current_namespace, &block)
    end

    def each(&block)
      @metric_definitions.values.map(&:call).each(&block)
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