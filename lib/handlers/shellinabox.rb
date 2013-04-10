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
      @chan = AMQP::Channel.new

      init_started_queue
      init_stopped_queue
    end

    def shutdown_amqp_stuff
      if not @running
        DaemonKit.logger.error "Error: Workspace service is not started"
        return
      end

      @chan.close
      @running = false
    end

    def init_started_queue
      queue_name = "#{DAEMON_CONF[:root_service]}.shellinabox.started"
      @start_queue = @chan.queue(queue_name, :durable => true)

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
      queue_name = "#{DAEMON_CONF[:root_service]}.shellinabox.stopped"
      @stop_queue = @chan.queue(queue_name, :durable => true)

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
