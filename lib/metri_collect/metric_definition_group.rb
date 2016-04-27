module MetriCollect
  class MetricDefinitionGroup
    def initialize(name, namespace, &body)
      @name = name
      @namespace = namespace
      @body = body
    end

    def call
      @definitions = []
      time = Time.now

      instance_eval(&@body)

      @definitions.each { |definition| definition.timestamp(time) }.map(&:call)
    end

    def metric(&block)
      @definitions ||= []
      @definitions << MetricDefinition.new(@name, @namespace, &block)
    end
  end
end