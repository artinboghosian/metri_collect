module MetriCollect
  class WatchDefinition
    def initialize(&body)
      @body = body
    end

    def call(metric)
      instance_eval(&@body)

      @name ||= "#{metric.name}"
      @evaluations ||= 1

      raise ArgumentError, "You must define a condition for watch '#{@name}'" if @condition.nil?

      Watch.new.tap do |watch|
        watch.name        = @name
        watch.description = @description
        watch.evaluations = @evaluations
        watch.statistic   = @condition.statistic
        watch.period      = @condition.period
        watch.threshold   = @condition.threshold
        watch.comparison  = @condition.comparison
      end
    end

    def name(name)
      @name = name
    end

    def description(description)
      @description = description
    end

    def evaluations(evaluations)
      @evaluations = evaluations
    end

    def condition(&body)
      @condition = Condition.new(&body)
    end

    class Condition
      attr_reader :statistic, :period, :threshold, :comparison

      def initialize(&body)
        instance_eval(&body)
        raise ArgumentError, "The given condition is invalid" if invalid?
      end

      def valid?
        !invalid?
      end

      def invalid?
        statistic.nil? || period.nil? || threshold.nil? || comparison.nil?
      end

      # ===========================================
      # statistic
      # ===========================================

      def average
        @statistic = :average
        self
      end

      def sum
        @statistic = :sum
        self
      end

      def minimum
        @statistic = :minimum
        self
      end

      def maximum
        @statistic = :maximum
        self
      end

      def sample_count
        @statistic = :sample_count
        self
      end

      # ===========================================
      # period
      # ===========================================

      def over_period(duration)
        @period = duration.to_i
        self
      end

      # ===========================================
      # threshold/comparison
      # ===========================================

      def >(value)
        @comparison = :>
        @threshold = value
        self
      end

      def >=(value)
        @comparison = :>=
        @threshold = value
        self
      end

      def <(value)
        @comparison = :<
        @threshold = value
        self
      end

      def <=(value)
        @comparison = :<=
        @threshold = value
        self
      end

      # ===========================================
      # misc
      # ===========================================

      def to_s
        "The #{statistic} over #{period} seconds is #{comparison} #{threshold}"
      end
    end
  end
end