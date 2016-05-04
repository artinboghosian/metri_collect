module MetriCollect
  class Watch
    attr_accessor :name, :description, :evaluations,
                  :statistic, :period, :comparison, :threshold

    def ==(other)
      self.class == other.class && name == other.name && description == other.description && evaluations == other.evaluations &&
        statistic == other.statistic && period == other.period && comparison == other.comparison && threshold == other.threshold
    end

    def self.from_object(obj)
      return obj if obj.nil? || obj.is_a?(Watch)
      return Watch.new.tap do |watch|
        watch.name        = obj[:name]
        watch.description = obj[:description]
        watch.evaluations = obj[:evaluations]
        watch.statistic   = obj[:statistic]
        watch.period      = obj[:period]
        watch.comparison  = obj[:comparison]
        watch.threshold   = obj[:threshold]
      end if obj.is_a?(Hash)
      raise ArgumentError, "Unable to convert #{obj.class} into watch"
    end

    def to_s
      "Watch '#{name}' (#{description}) - The #{statistic} over #{period} seconds is #{comparison} #{threshold} for #{evaluations} evaluation(s)"
    end
  end
end