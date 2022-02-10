module MetriCollect
  class MetricCollection
    include Enumerable

    attr_reader :application

    def initialize(application, namespace)
      @application = application
      @namespaces  = [namespace]
      @roles       = []
      @groups      = {}
    end

    def namespace(namespace, options = {}, &block)
      if options[:roles]
        @roles << options[:roles] if options[:roles]
      end

      @namespaces.push(namespace)
      yield
      @namespaces.pop

      @roles.pop if options[:roles]
    end

    def group(name, options = {}, &block)
      id = Metric.id(name, current_namespace)
      raise ArgumentError, "Metric '#{id}' has already been defined" if metric_defined?(id)
      @groups[id] = MetricDefinitionGroup.new(application, current_namespace, name, options.merge(roles: current_roles), &block)
    end

    def metric(name, options = {}, &block)
      group(name, options) { metric(&block) }
    end

    def each(&block)
      @groups.values.flat_map(&:call).each(&block)
    end

    def ids(options={})
      roles = options.fetch(:roles, [])
      include_external = options.fetch(:include_external, true)
      external_only = options.fetch(:external_only, false)

      groups = @groups.select do |id, group|
        (group.roles.empty? || (roles & group.roles).any?) &&
        (include_external || !group.external?) &&
        (!external_only || group.external?)
      end

      groups.keys
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
      @roles.dup.flatten
    end

    def metric_defined?(id)
      @groups.key?(id)
    end
  end
end
