module MetriCollect
  class Metric
    attr_writer   :dimensions, :unit, :timestamp
    attr_accessor :name, :namespace, :value, :watches

    def id
      self.class.id(name, namespace)
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

    def to_s
      dimension_string = dimensions.empty? ? "none" : dimensions.map { |d| "#{d[:name]}: #{d[:value]}" }.join(", ")
      "Metric '#{id}' has value '#{value}' (dimensions: #{dimension_string}) at #{timestamp}"
    end

    def self.id(name, namespace)
      "#{namespace}/#{name}"
    end

    def self.from_object(obj)
      return obj if obj.nil? || obj.is_a?(Metric)
      return Metric.new.tap do |metric|
        metric.name       = obj[:name]
        metric.namespace  = obj[:namespace]
        metric.value      = obj[:value]
        metric.timestamp  = obj[:timestamp]
        metric.dimensions = obj[:dimensions]
        metric.watches    = obj.fetch(:watches, []).map {|w| Watch.from_object(w)}
      end if obj.is_a?(Hash)
      raise ArgumentError, "Unable to convert #{obj.class} into metric"
    end
  end
end