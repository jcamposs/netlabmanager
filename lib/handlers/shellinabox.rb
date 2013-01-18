module NetlabHandler
  class Shellinabox < NetlabManager::ServiceHandler
    def start
      init_amqp_stuff
      return true
    end

    def stop
      #TODO:
    end

    private
    def init_amqp_stuff
      init_started_queue
    end

    def init_started_queue
      @start_chan = AMQP::Channel.new
      queue_name = "#{DAEMON_CONF[:root_service]}.shellinabox.started"
      @start_queue = @start_chan.queue(queue_name, :durable => true)

      @start_queue.subscribe do |metadata, payload|
        DaemonKit.logger.debug "[requests] started shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          #Todo
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
          #Todo:
        end
      end
    end
  end
end
