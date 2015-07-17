module MetriCollect
  class Metric
    attr_writer   :dimensions
    attr_accessor :name, :namespace, :value, :unit, :timestamp

    def id
      "#{namespace}/#{name}"
    end

    def dimensions
      @dimensions || []
    end

    def ==(other)
      id == other.id
    end
  end
end