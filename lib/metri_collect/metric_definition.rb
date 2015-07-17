module MetriCollect
  class MetricDefinition
    def initialize(name, namespace, &body)
      @name      = name
      @namespace = namespace
      @body      = body
    end

    def call
      instance_eval(&@body)

      Metric.new.tap do |metric|
        metric.name       = @name
        metric.namespace  = @namespace
        metric.value      = @value
        metric.unit       = @unit
        metric.timestamp  = @timestamp
        metric.dimensions = @dimensions
      end
    end

    def name(name)
      @name = name
    end

    def namespace(namespace)
      @namespace = namespace
    end

    def value(value, unit: :count)
      @value = value
      @unit  = unit
    end

    def dimensions(dimensions = {})
      @dimensions = dimensions.map do |k,v|
        { name: k, value: v }
      end
    end

    def timestamp(timestamp)
      @timestamp = timestamp
    end
  end
end