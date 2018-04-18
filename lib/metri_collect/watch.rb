module MetriCollect
  class Watch
    attr_accessor :name, :description, :evaluations, :statistic, :period, :comparison, :threshold, :urgency, :missing
    attr_accessor :metric_name, :namespace, :dimensions

    def ==(other)
             self.class == other.class &&
                   name == other.name &&
            description == other.description &&
            evaluations == other.evaluations &&
              statistic == other.statistic &&
                 period == other.period &&
             comparison == other.comparison &&
              threshold == other.threshold &&
                urgency == other.urgency &&
                missing == other.missing &&
            metric_name == other.metric_name &&
              namespace == other.namespace &&
             dimensions == other.dimensions
    end

    def self.from_object(obj)
      case obj
      when Watch, NilClass
        obj
      when Hash
        Watch.new.tap do |watch|
          watch.name = obj[:name]
          watch.description = obj[:description]
          watch.evaluations = obj[:evaluations]
          watch.statistic = obj[:statistic]
          watch.period = obj[:period]
          watch.comparison = obj[:comparison]
          watch.threshold = obj[:threshold]
          watch.urgency = obj[:urgency]
          watch.missing = obj[:missing]
          watch.metric_name = obj[:metric_name]
          watch.namespace = obj[:namespace]
          watch.dimensions = obj[:dimensions]
        end
      else
        raise ArgumentError, "Unable to convert #{obj.class} into watch"
      end
    end

    def to_s
      "Watch '#{name}' (#{description}) - The #{statistic} over #{period} seconds is #{comparison} #{threshold} for #{evaluations} evaluation(s)"
    end
  end
end