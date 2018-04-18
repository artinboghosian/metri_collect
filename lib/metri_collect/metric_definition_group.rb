module MetriCollect
  class MetricDefinitionGroup
    attr_reader :name, :namespace, :options

    def initialize(name, namespace, options = {}, &body)
      @name = name
      @namespace = namespace
      @options = options
      @body = body
    end

    def call
      @definitions = []
      time = Time.now

      instance_eval(&@body)

      begin
        @definitions.each { |definition| definition.timestamp(time) }.map(&:call)
      rescue
        []
      end
    end

    def metric(&block)
      @definitions ||= []
      @definitions << MetricDefinition.new(@name, @namespace, @options, &block)
    end

    def roles
      @options[:roles]
    end

    def external?
      @options[:external]
    end
  end
end