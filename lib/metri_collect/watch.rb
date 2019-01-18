module MetriCollect
  class Watch
    attr_accessor :name, :description, :evaluations, :statistic, :period, :comparison, :threshold, :urgency, :missing
    attr_accessor :metric_name, :namespace, :dimensions, :actions

    def ==(other)
      compare(other, :class, :name, :description, :evaluations, :statistic, :period, :comparison, :threshold, :urgency, :missing, :metric_name, :namespace, :dimensions, :actions)
    end

    def compare(other, *attrs)
      attrs.inject(true) do |result, attribute|
        thisVal  = self.send(attribute)
        otherVal = other.send(attribute)

        if thisVal == otherVal
          next true
        else
          puts "Watch '#{name}': Difference in #{attribute}: '#{thisVal}' != '#{otherVal}'"
          break false
        end
      end
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
          watch.actions = obj[:actions]
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