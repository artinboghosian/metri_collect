require 'json'

module MetriCollect
  class MetricDefinition
    attr_reader :application, :namespace, :name, :options

    def initialize(application, namespace, name, options={}, &body)
      @application = application
      @namespace   = namespace
      @name        = name
      @options     = options
      @dimensions  = []
      @templates   = []
      @body        = body
      @value       = nil
      @unit        = nil
    end

    def call
      @dimensions = []
      instance_eval(&@body)
      @templates.each { |template| template.apply(self) }

      Metric.new.tap do |metric|
        metric.name       = @name
        metric.namespace  = @namespace
        metric.unit       = @unit
        metric.timestamp  = @timestamp
        metric.dimensions = @dimensions

        metric.external   = external?
        metric.roles      = roles

        metric.value = begin
          @value.is_a?(Proc) ? @value.call : @value
        rescue
          nil
        end
      end
    end

    def template(*names)
      names.each { |name| @templates << MetricTemplate.fetch(name) }
    end

    def name(name)
      @name = name
    end

    def namespace(namespace)
      @namespace = namespace
    end

    def value(value=nil, unit: :count, &block)
      if value == :external
        options[:external] = true
        return
      end

      raise RuntimeError, "Cannot call #value on external metric" if external?
      raise RuntimeError, "Cannot provide a value argument AND a block" if value && block_given?

      @value = value || block
      @unit  = unit
    end

    def dimensions(dimensions = {})
      dimensions.each do |k,v|
        @dimensions << { name: k, value: v }
      end
    end

    def timestamp(timestamp)
      @timestamp = timestamp
    end

    def watch(name=@name, &block)
      application.watches << WatchDefinition.new(name, @namespace, @name, @dimensions, &block).call
    end

    def external?
      options.fetch(:external, false)
    end

    def roles
      options.fetch(:roles, nil)
    end

    def self.build_metric(obj)
      return obj if obj.nil? || obj.is_a?(Metric)

      if obj.is_a?(Hash)
        obj_hash = obj.dup
        name = obj_hash.delete(:name)
        namespace = obj_hash.delete(:namespace)

        metric_definition = MetricDefinition.new(nil, namespace, name) do
          obj_hash.each do |attribute,value|
            send(attribute, value) if respond_to?(attribute)
          end
        end

        metric_definition.call
      else
        raise ArgumentError, "Unable to convert #{obj.class} into metric"
      end
    end
  end
end