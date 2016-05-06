module MetriCollect
  class MetricCollection
    include Enumerable

    def initialize(namespace)
      @namespaces  = [namespace]
      @roles       = []
      @groups      = {}
    end

    def namespace(namespace, options = {}, &block)
      @namespaces.push(namespace)
      @roles = options[:roles] if options[:roles]
      yield
      @roles.pop
      @namespaces.pop
    end

    def group(name, &block)
      id = Metric.id(name, current_namespace)

      if metric_defined?(id)
        raise ArgumentError, "Metric '#{id}' has already been defined"
      else
        @groups[id] = MetricDefinitionGroup.new(name, current_namespace, roles: current_roles, &block)
      end
    end

    def metric(name, &block)
      group(name) { metric(&block) }
    end

    def each(&block)
      @groups.values.flat_map(&:call).each(&block)
    end

    def ids(roles)
      @groups.select { |id, group| group.match_roles?(roles) }.keys
    end

    def [](id)
      raise ArgumentError, "Metric '#{id}' has not been defined" unless metric_defined?(id)
      @groups[id].call
    end

    private

    def current_namespace
      @namespaces.join("/")
    end

    def current_roles
      @roles.dup
    end

    def metric_defined?(id)
      @groups.key?(id)
    end
  end
end