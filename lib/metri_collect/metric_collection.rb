module MetriCollect
  class MetricCollection
    include Enumerable

    def initialize(namespace)
      @namespaces  = [namespace]
      @roles       = []
      @groups      = {}
      @external    = false
    end

    def namespace(namespace, options = {}, &block)
      @ext_prev  = @external

      if options[:external]
        @namespaces = []
        @external   = true
      end

      if options[:roles]
        @roles << options[:roles] if options[:roles]
      end

      @namespaces.push(namespace)
      yield
      @namespaces.pop

      @roles.pop if options[:roles]
      @external = @ext_prev if options[:external]
    end

    def group(name, &block)
      id = Metric.id(name, current_namespace)

      if metric_defined?(id)
        raise ArgumentError, "Metric '#{id}' has already been defined"
      else
        @groups[id] = MetricDefinitionGroup.new(name, current_namespace, roles: current_roles, external: external?, &block)
      end
    end

    def metric(name, &block)
      group(name) { metric(&block) }
    end

    def each(&block)
      @groups.values.flat_map(&:call).each(&block)
    end

    def ids(options={})
      roles = options.fetch(:roles, nil)
      include_external = options.fetch(:include_external, true)

      groups = @groups.select do |id, group|
        (roles.empty? || (roles & group.roles).any?) &&
        (include_external || !group.external?)
      end

      groups.keys
    end

    def [](id)
      raise ArgumentError, "Metric '#{id}' has not been defined" unless metric_defined?(id)
      @groups[id].call
    end

    def external?
      @external == true
    end

    private

    def current_namespace
      @namespaces.join("/")
    end

    def current_roles
      @roles.dup.flatten
    end

    def metric_defined?(id)
      @groups.key?(id)
    end
  end
end