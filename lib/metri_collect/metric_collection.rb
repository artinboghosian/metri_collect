module MetriCollect
  class MetricCollection
    include Enumerable

    def initialize(application)
      @application        = application
      @namespaces         = [application.name]
      @metric_definitions = []
    end

    def namespace(namespace, &block)
      @namespaces.push(namespace)
      yield
      @namespaces.pop
    end

    def metric(name, &block)
      @metric_definitions.push(MetricDefinition.new(name, current_namespace, &block))
    end

    def each(&block)
      @metric_definitions.map(&:call).each(&block)
    end

    private

    def current_namespace
      @namespaces.join("/")
    end
  end
end