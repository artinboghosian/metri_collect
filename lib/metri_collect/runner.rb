
module MetriCollect
  class Runner

    attr_reader :application, :options, :status

    def initialize(name, options={})
      @application = MetriCollect[name]

      raise ArgumentError, "Application '#{name}' not found" if @application.nil?

      @options = options
      @running = false
    end

    # ===================================================================
    # control methods
    # ===================================================================

    def start
      return if running?

      log("Starting Runner...")
      run!
    end

    def stop
      return unless running?

      log("Stopping Runner...")
      @running = false
    end

    def running?
      @running
    end

    # ===================================================================
    # options
    # ===================================================================

    def frequency
      options[:frequency] || (2 * 60)
    end

    def roles
      options.fetch(:roles, [])
    end

    def logger
      options[:logger] || Logger.new(STDOUT)
    end

    def iterations
      options[:iterations]
    end

    def initial_worker_count
      options.fetch(:initial_worker_count, 5)
    end

    def max_worker_count
      options.fetch(:max_worker_count, 20)
    end

    # ===================================================================
    # forking callbacks
    # ===================================================================

    def before_fork(&block)
      @before_fork = block
    end

    def after_fork(&block)
      @after_fork = block
    end

    # ===================================================================
    # helper classes
    # ===================================================================

    class ProcessInfo
      attr_reader :pid, :group, :command

      def initialize(pid, group, command)
        @pid, @group, @command = pid, group, command
      end

      def kill(signal)
        Process.kill(signal, pid)
      end

      def kill_group(signal)
        `kill -s #{signal} -- -#{group}`
      end
    end

    protected

    # ===================================================================
    # main method
    # ===================================================================

    def run!

      return if running?

      @running = true

      # call this thread 'master'...
      rename_process!('master')

      # stop any existing masters...
      stop_old_masters!

      # initialize signaling...
      init_signaling

      # call the before-fork callback (if defined)...
      @before_fork.call unless @before_fork.nil?

      if roles.any?
        log "Running #{roles.join(", ")} metrics."
      else
        log "Running non role specific metrics"
      end

      # get all of the metric ids we should process...
      metric_ids = application.metric_ids(roles)

      5.times do
        metric_ids += application.metric_ids(roles)
      end

      # create workers...
      add_workers(initial_worker_count)

      # start all the workers...
      start_workers

      # initialize run tracking variables...
      next_run_at = Time.now
      last_run_at = nil
      finished_at = nil
      iteration_count = 0

      # keep queueing work for each cycle...
      while running?
        current_time = Time.now

        # wait for the next run and be sure to
        # record the queue completion time as well...
        if current_time < next_run_at
          finished_at = current_time if queue.empty? && finished_at.nil?
          sleep 1; next
        end

        # record performance
        if queue.empty?
          log("Queue empty, finished_at: #{finished_at}")
          record_performance((finished_at - last_run_at).to_f / frequency) if finished_at
        else
          log("Queue NOT empty, #{queue.length} remaining...")
          record_performance(metric_ids.count.to_f / (metric_ids.count - queue.size))
          queue.clear
        end

        # display performance data...
        log("Beginning cycle; Performance: #{performance_history} (avg: #{average_performance})")

        # adjust the worker pool size if needed...
        adjust_worker_count!

        # queue the additional work...
        metric_ids.each do |metric_id|
          queue.push(metric_id)
        end

        # update the run times...
        last_run_at = next_run_at
        next_run_at = last_run_at + frequency
        finished_at = nil

        # if a maximum number of iterations has been specified,
        # and we have reached that number of iterations, then exit...
        if iterations != nil && (iteration_count += 1) >= iterations
          log("Stopping runner because it has reached the desired iteration count of #{iterations}")
          break
        end

      end

      # stop all workers...
      stop_workers

      # read the signal message to see what to do...
      log("Runner has been stopped")
    end

    # ===================================================================
    # worker management
    # ===================================================================

    def workers
      @workers ||= []
    end

    def start_workers
      workers.each { |w| w.start }
    end

    def stop_workers
      workers.each { |w| w.stop }
    end

    def add_workers(count, start=false)
      count.times do |i|
        workers << MetriCollect::Worker.new(application, queue, [process_name, @application.name, "worker[#{workers.count}]"].join(" ")).tap do |worker|
          worker.start if start
        end
      end
    end

    def remove_workers(count)
      target = [workers.count - count, 1].max

      while workers.count > target
        workers.pop.stop
      end
    end

    def adjust_worker_count!
      average = average_performance

      return workers.count if average.nil?

      target_count = if average < 0.50 && workers.count > initial_worker_count
        log "Performance is great, average #{average} => removing workers"
        workers.count - 1
      elsif average > 0.80 && workers.count < max_worker_count
        optimal = (workers.count * (average / 0.70)).to_i
        log "Performance is bad, average: #{average}, workers: #{workers.count} => optimal workers = #{optimal}"
        [optimal, max_worker_count].min
      end

      target_count ||= workers.count
      diff = [target_count - workers.count, -1].max

      return if diff == 0

      log "Adjusting worker count by #{diff} (new count will be #{workers.count + diff})..."

      diff > 0 ? add_workers(diff, true) : remove_workers(1)
    end

    # ===================================================================
    # performance monitoring
    # ===================================================================

    def record_performance(performance_data)
      performance_history << performance_data.round(2)

      if performance_history.length > 5
        performance_history.shift
      end
    end

    def average_performance
      performance_history.any? ? (performance_history.inject(0) { |sum, x| sum + x }.to_f / performance_history.count) : nil
    end

    def performance_history
      @performance_history ||= []
    end

    # ===================================================================
    # signaling
    # ===================================================================

    def init_signaling
      Signal.trap("TERM") do
        stop
      end

      Signal.trap("INT") do
        stop
      end
    end

    def queue
      @queue ||= Queue.new
    end

    # ===================================================================
    # existing instance management
    # ===================================================================

    def existing_instances(filter="")
      instances_raw = `ps xao pid,pgrp,cmd | grep '#{process_name} #{name_grep_string} #{filter}' | grep -iv #{Process.pid} | awk '{print $1 "\t" $2 "\t" $3}'`
      instances_raw.split("\n").map do |row|
        pid, group, command = row.split("\t")
        ProcessInfo.new(pid.to_i, group.to_i, command)
      end
    end

    def existing_groups
      existing_instances.inject({}) do |memo, instance|
        memo[instance.group] ||= []
        memo[instance.group] << instance
        memo
      end
    end

    def existing_masters
      existing_instances("master")
    end

    def stop_old_masters!
      masters = existing_masters
      all_gone = false

      return if existing_instances.empty?

      log("Sending shutdown signal (TERM) to old masters: #{masters.map(&:pid).join(", ")} (new PID: #{Process.pid})")

      # first, be nice and send a friendly TERM signal...
      masters.each { |master| master.kill('TERM') }

      # then, wait a couple secs and check to see if they're gone...
      log("Waiting up to 10 seconds for existing processes to terminate", false)

      (0..9).each do |i|
        remaining = existing_instances.count
        (all_gone = true; return) if remaining == 0
        log("  There are still #{remaining} existing processes.  Waiting up to #{10 - i} more seconds...")
        sleep 1
      end

      # if they're still hanging around, it's time to bring out the
      # bug guns (aka SIGKILL)...
      log("At least one existing process has not terminated, sending kill signal...")

      # kill (SIGKILL) each process group...
      existing_groups.each do |group, processes|
        log("Killing group #{group} (PIDs: #{processes.map(&:pid).join(', ')})")
        processes.first.kill_group('KILL') if processes.any?
      end

      # wait 1 second and check the outcome...
      sleep 1; log("After cleanup, there are #{existing_instances.count} existing instances still running.")
    end

    def name_grep_string
      [ "[#{application.name[0]}]", application.name.length > 1 ? application.name[1..-1] : "" ].join
    end

    # ===================================================================
    # helper methods
    # ===================================================================

    def process_name
      @process_name ||= $0.dup
    end

    def rename_process!(name)
      $0 = ([ process_name, @application.name, name ]).join(' ')
    end

    def log(message, newline=true)
      puts "#{Time.now.strftime("%m/%d/%Y %I:%M%p")} [#{Process.pid}] >>> #{message}#{newline ? "\n" : ""}"
    end

  end
end
