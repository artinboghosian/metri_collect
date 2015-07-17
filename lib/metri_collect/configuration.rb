module MetriCollect
  class Configuration
    def [](key)
      applications[key]
    end

    def application(name, &block)
      applications[name] = Application.new(name).tap do |application|
        yield(application)
      end
    end

    def add_publisher(key, publisher)
      Publisher[key] = publisher
    end

    private

    def applications
      @applications ||= {}
    end
  end
end