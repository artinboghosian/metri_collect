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
      @watches     = {}
    end

    def call
      @dimensions = []
      instance_eval(&@body)
      apply_templates
      @watches.each do |name, block|
        application.watches << WatchDefinition.new(name, prefixed_namespace, @name, @dimensions, &block).call
      end

      Metric.new.tap do |metric|
        metric.name       = @name
        metric.namespace  = prefixed_namespace
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

    def apply_templates
      return if @templates.empty?

      to_apply = @templates.dup
      to_apply.each do |template|
        template.apply(self)
        @templates.delete(template)
      end
    end

    def name(name)
      @name = name
    end

    def namespace(namespace)
      @namespace = namespace
    end

    def prefixed_namespace
      return @namespace unless options[:prefix]

      @namespace.split('/').insert(1, options[:prefix]).join('/')
    end

    def value(value = nil, unit: :count, &block)
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
      @watches[name] = block
    end

    def watches(watch_array = nil)
      apply_templates
      watch_array.each do |watch_def|
        watch_def.merge!({
          namespace: prefixed_namespace,
          dimensions: @dimensions
        })
        application.watches << Watch.from_object(watch_def)
      end
    end

    def external?
      options.fetch(:external, false)
    end

    def roles
      options.fetch(:roles, nil)
    end

    def self.build_metric(obj, opts = {})
      return obj if obj.nil? || obj.is_a?(Metric)

      if obj.is_a?(Hash)
        obj_hash = obj.dup
        application = opts.delete(:application)
        name = obj_hash.delete(:name)
        base_namespace = obj_hash.delete(:namespace)
        obj_template = obj_hash.delete(:template)

        metric_definition = MetricDefinition.new(application, base_namespace, name, opts) do
          template(obj_template) if obj_template

          obj_hash.each do |attribute, value|
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
