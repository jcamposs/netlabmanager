module NetlabHandler
  class Workspace < NetlabManager::ServiceHandler
    def start
      @chan = AMQP::Channel.new
      queue_name = "#{DAEMON_CONF[:root_service]}.workspace.state"
      @queue = @chan.queue(queue_name, :durable => true)
      @running = true

      @queue.subscribe(:ack => true) do |metadata, payload|
        DaemonKit.logger.debug "[requests] Workspace id #{payload}."
        begin
          req = JSON.parse(payload)
          EventMachine.synchrony do
            rep = workspace_state_reply req["workspace"]
            reply(metadata, rep)
          end
        rescue
          rep = error_msg("Protocol error")
          reply(metadata, rep)
        end
      end

      return true
    end

    def stop
      if not @running
        DaemonKit.logger.error "Error: Workspace service is not started"
        return
      end

      @chan.close
      @running = false
    end

    private
    def reply(metadata, reply)
      @chan.default_exchange.publish(reply,
        :routing_key => metadata.reply_to,
        :correlation_id => metadata.message_id,
        :content_type => "application/json",
        :mandatory => true)
      metadata.ack
    end

    def error_msg(cause)
      error = true
      return NetlabManager.render("workspace_state.js.erb", binding)
    end

    def workspace_state_reply id
      nodes = {}
      error = false
      VirtualMachine.find_all_by_workspace_id(id).each do |vm|
        nodes[vm.name] = vm.state
      end

      return NetlabManager.render("workspace_state.js.erb", binding)
    end
  end
end
