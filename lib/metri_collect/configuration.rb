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

    private

    def applications
      @applications ||= {}
    end
  end
end