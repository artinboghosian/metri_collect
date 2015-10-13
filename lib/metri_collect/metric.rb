module MetriCollect
  class Metric
    attr_writer   :dimensions, :unit, :timestamp
    attr_accessor :name, :namespace, :value

    def id
      "#{namespace}/#{name}"
    end

    def unit
      @unit || :count
    end

    def timestamp
      @timestamp || Time.now
    end

    def dimensions
      @dimensions || []
    end

    def ==(other)
      id == other.id
    end

    def self.from_object(obj)
      return obj if obj.nil? || obj.is_a?(Metric)
      return Metric.new.tap do |metric|
        metric.name       = obj[:name]
        metric.namespace  = obj[:namespace]
        metric.value      = obj[:value]
        metric.timestamp  = obj[:timestamp]
        metric.dimensions = obj[:dimensions]
      end if obj.is_a?(Hash)
      raise ArgumentError, "Unable to convert #{obj.class} into metric"
    end
  end
end