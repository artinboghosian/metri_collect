

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
      write_message("EXIT")
    end

    def running?
      @running
    end

    # ===================================================================
    # options
    # ===================================================================

    def frequency
      options[:frequency] || 2.minutes
    end

    def filter
      options[:filter]
    end

    def logger
      options[:logger] || Logger.new(STDOUT)
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
      @run_time = Time.now
      metrics = {}
      count = 0

      # call this thread 'master'...
      rename_process!('master')

      # stop any existing masters...
      stop_old_masters!

      # initialize signaling...
      init_signaling

      # call the before-fork callback (if defined)...
      @before_fork.call unless @before_fork.nil?

      # create workers for each metric...
      application.metrics.each do |metric|

        # skip this metric if we are filtering it...
        next if filter && metric.id !~ filter

        # fork, and store the process
        metrics[metric.id] = fork do
          run_worker!(metric, count)
        end

        count += 1

      end

      # wait for the threads to exit. this should
      # only happen when we catch a stop or restart signal...
      Process.waitall

      # read the signal message to see what to do...
      message = @read_pipe.read_nonblock(4) || '(none)'
      log("App Metrics has been stopped with message '#{message}'")

    end

    def run_worker!(metric, id)

      # trap the term signal and exit when we receive it
      Signal.trap("TERM") { exit }

      # rename this process as a worker
      rename_process!("worker[#{id}]")

      next_run = 0
      last_run = nil
      last_duration = nil

      # call the after-fork callback (if defined)...
      @after_fork.call unless @after_fork.nil?

      loop do

        # sleep while waiting for next run...
        while Time.now < next_run

          # wait up to 5 seconds for a message
          # on the read-end of the pipe.  if one is
          # received, that means it's time to exit...
          message = read_message

          unless message.nil?
            log("Terminating this thread because an exit message was received from the parent")
            exit
          end

          # make sure we're not in a weird state...
          # if the parent pid is 1 (INIT) then we've
          # been abandoned, so we should exit.
          parent_pid = Process.ppid
          parent_ok = (parent_pid != 1)

          unless parent_ok
            log("Terminating this thread because it was abandoned (parent PID: #{parent_pid})")
            exit
          end

        end

        log("Running metric: #{metric.id} (Last run: #{last_run.try(:to_s) || 'never'}, Duration: #{last_duration || 'n/a'})")

        run_time = next_run
        next_run = run_time + time_span
        last_run = run_time

        begin
          application.publish(metric)
          last_duration = (Time.now - last_run)
        rescue Exception => ex
          log("Child processing metric #{metric.id} caught exception:\n#{ex.message}\n#{ex.backtrace.join("\n")}")
        end
      end
    end

    # ===================================================================
    # signaling
    # ===================================================================

    def init_signaling
      # create a pipe for ipc...
      @read_pipe, @write_pipe = IO.pipe

      Signal.trap("TERM") do
        stop
      end
    end

    def read_message(timeout=5)
      IO.select([@read_pipe], nil, nil, timeout)
    end

    def write_message(message)
      @write_pipe.write(message)
    end

    # ===================================================================
    # existing instance management
    # ===================================================================

    def existing_instances(filter="")
      instances_raw = `ps xao pid,pgrp,cmd | grep '#{name_grep_string} #{filter}' | grep -iv #{Process.pid} | awk '{print $1 "\t" $2 "\t" $3}'`
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
      $0 = ([ process_name, name ]).join(' ')
    end

    def log(message, newline=true)
      puts "#{Time.now.strftime("%m/%d/%Y %I:%M%p")} [#{Process.pid}] >>> #{message}#{newline ? "\n" : ""}"
    end

  end
end
