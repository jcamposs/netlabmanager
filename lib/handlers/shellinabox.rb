module NetlabHandler
  class ShellinaboxHandler < NetlabManager::ServiceHandler
    def start
      init_amqp_stuff
      @running = true
      return true
    end

    def stop
      shutdown_amqp_stuff
    end

    private
    def init_amqp_stuff
      init_started_queue
      init_stopped_queue
    end

    def shutdown_amqp_stuff
      if not @running
        DaemonKit.logger.error "Error: Workspace service is not started"
        return
      end

      shutdown_started_queue
      shutdown_stopped_queue
      @running = false
    end

    def init_started_queue
      @start_chan = AMQP::Channel.new
      queue_name = "#{DAEMON_CONF[:root_service]}.shellinabox.started"
      @start_queue = @start_chan.queue(queue_name, :durable => true)

      @start_queue.subscribe do |metadata, payload|
        DaemonKit.logger.debug "[requests] started shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          EventMachine.synchrony do
            uptade_started_daemon(req)
          end
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end

    def init_stopped_queue
      @stop_chan = AMQP::Channel.new
      queue_name = "#{DAEMON_CONF[:root_service]}.shellinabox.stopped"
      @stop_queue = @stop_chan.queue(queue_name, :durable => true)

      @stop_queue.subscribe do |metadata, payload|
        DaemonKit.logger.debug "[requests] stopped shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          EventMachine.synchrony do
            uptade_stopped_daemon(req)
          end
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end

    def shutdown_started_queue
      @start_chan.close
    end

    def shutdown_stopped_queue
      @stop_chan.close
    end

    def uptade_started_daemon(msg)
      begin
        shell = Shellinabox.find(msg["shellinabox"])
        shell.host_name = msg["host_name"]
        shell.port_number = msg["port_number"]
        shell.save
      rescue Exception => e
        DaemonKit.logger.error e.message
        DaemonKit.logger.error e.backtrace
      end
    end

    def uptade_stopped_daemon(msg)
      msg["shellinaboxes"].each do |id|
        begin
          shell = Shellinabox.find(id)
          shell.destroy if shell.host_name == msg["host_name"]
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end
  end
end
