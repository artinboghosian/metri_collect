module MetriCollect
  class MetricDefinitionGroup
    attr_reader :application, :namespace, :name, :options, :definitions

    def initialize(application, namespace, name, options = {}, &body)
      @application = application
      @namespace   = namespace
      @name        = name
      @options     = options
      @body        = body
      @definitions = []
    end

    def call(evaluate=true)
      time    = Time.now
      message = evaluate ? :evaluate : :call

      reset_definitions!
      instance_eval(&@body)

      definitions.each do |definition|
        definition.timestamp(time)
      end.map(&message)
    end

    def metric(&block)
      definitions << MetricDefinition.new(application, namespace, name, options, &block)
    end

    def roles
      options[:roles]
    end

    def external?
      options[:external]
    end

    private

    def reset_definitions!
      definitions.clear
    end
  end
end