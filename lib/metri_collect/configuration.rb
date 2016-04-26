module MetriCollect
  class Configuration
    def [](key)
      applications[key]
    end

    def application(name, &block)
      applications[name] = Application.new(name).tap { |application| yield(application) }
    end

    def template(key, &block)
      MetricTemplate.add_template(key, &block)
    end

    def add_publisher(key, publisher)
      Publisher.add_publisher(key, publisher)
    end

    def default_application
      applications.values.first
    end

    private

    def applications
      @applications ||= {}
    end
  end
end