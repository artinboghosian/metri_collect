module MetriCollect
  class Worker
    attr_reader :application, :name

    def initialize(application, queue, name, &block)
      @application = application

      @queue   = queue
      @name    = name
      @parent  = true
      @running = false
      @ready   = false

      @after_fork = block
    end

    def start
      return if running?

      @running = true
      @ready   = true

      # initialize pipes for IPC...
      @parent_read, @child_write = IO.pipe
      @child_read, @parent_write = IO.pipe

      # fork!
      if (@child_pid = fork)

        # if we're the parent process,
        # close the child pipes...
        @child_read.close
        @child_write.close

        # start a thread to run the
        # parent event loop...
        Thread.new do
          parent_event_loop
        end

      else
        @parent = false
        $0 = name

        # if we're the child process,
        # close the parent pipes...
        @parent_read.close
        @parent_write.close

        # call the after-fork callback (if defined)...
        @after_fork.call unless @after_fork.nil?

        # run the child event loop...
        child_event_loop

        exit
      end
    end

    def stop
      if running? && parent? && @child_pid
        @running = false
        dispatch_exit_message

        # wait for the child process to exit...
        Process.waitpid(@child_pid)
      end
    end

    # ===============================================================
    # status methods
    # ===============================================================

    def running?
      @running
    end

    def ready?
      @ready
    end

    def parent?
      @parent
    end

    def child?
      !parent?
    end

    private

    # ===============================================================
    # main operations
    # ===============================================================

    # main event loop for the parent process. this loop
    # checks to see if the child is ready for more work, and
    # if so, dispatches the work to the child. this loop
    # is also responsible for watching for exit messages and
    # signals and passing those along to the child as well...
    def parent_event_loop
      begin
        while running?

          # check for child work requests...
          check_requests

          # keep looping unless the child
          # is ready for more work...
          next unless ready? && (work_item = dequeue_work)

          # stop if we've received an exit message...
          (stop; break) if exit_message?(work_item)

          # dispatch the work to the child...
          dispatch_work(work_item)
        end
      rescue SystemExit, Interrupt
      ensure
        stop
      end
    end

    def child_event_loop
      while running?
        # check to see if we have any work
        # to do. if so, do it, if not, request it...
        work_item = receive_work

        unless work_item
          request_work
          next
        end

        # if we received the exit message,
        # then break out of the run loop...
        if exit_message?(work_item)
          @running = false
          break
        end

        begin
          log "Child processing metric '#{work_item}'..."
          application.publish(work_item)
        rescue Exception => ex
          log "Child processing metric '#{work_item}' caught exception:\n#{ex.message}\n#{ex.backtrace.join("\n")}"
        end
      end
    end

    # ===============================================================
    # queue processing
    # ===============================================================

    # grab an item of work off the queue...
    def dequeue_work
      if @queue.length > 0
        @queue.pop(true) rescue nil
      end
    end

    # check to see if the work item is
    # the signal to exit...
    def exit_message?(work_item)
      work_item == "EXIT"
    end

    # ===============================================================
    # child messages
    # ===============================================================

    # signal readiness to parent by sending
    # PID and marking self as ready for work...
    def request_work
      write_message(@child_write, Process.pid.to_s) unless ready?
      @ready = true
    end

    # wait up to :timeout seconds for work
    # from the parent process. if work is available
    # return it, otherwise return nil...
    def receive_work(timeout=1)
      if work_item = read_message(@child_read)
        @ready = false
        work_item
      end
    end

    # ===============================================================
    # parent messages
    # ===============================================================

    # check for work requests from child and mark
    # self as ready if there are any available...
    def check_requests(timeout=1)
      if work_item = read_message(@parent_read)
        @ready = true
        work_item
      end
    end

    # if the child is ready for more work, and if
    # there is work in the queue, then dispatch
    # the work to the child and mark self as busy...
    def dispatch_work(work_item)
      return unless ready?
      @ready = false
      write_message(@parent_write, work_item.to_s)
    end

    # dispatch the exit message to the child process...
    def dispatch_exit_message
      write_message(@parent_write, "EXIT")
    end

    # ===============================================================
    # messages
    # ===============================================================

    # wait up to timeout (seconds) for the given pipe to
    # become writeable (using #select), then write the given
    # message to the pipe...
    def write_message(pipe, message, timeout=1)
      raise ArgumentError, "Message too long (#{message.length} > 9999)" if message.length > 9999

      _, writeable, = IO.select(nil, [pipe], nil, timeout)

      if writeable && writeable[0]
        writeable[0].write("#{message.length.to_s.rjust(4, '0')}#{message}")
      end
    end

    # wait up to timeout (seconds) for a message to become
    # readable on the given pipe (using #select). if a message
    # is readable, read and return it. otherwise return nil...
    def read_message(pipe, timeout=1)
      readable, = IO.select([pipe], nil, nil, timeout)

      if readable && readable[0]
        length  = readable[0].read(4).to_i
        message = readable[0].read(length)

        message
      end
    end

    # ===============================================================
    # logging
    # ===============================================================

    def log(message)
      puts "[#{parent? ? 'P' : 'C'}:#{Process.pid}] #{message}"
    end
  end
end