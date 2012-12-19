require 'erb'

module NetlabHandler
  class Workspace < NetlabManager::ServiceHandler
    def start
      @chan = AMQP::Channel.new
      queue_name = "#{DAEMON_CONF[:root_service]}.workspace.state"
      @queue = @chan.queue(queue_name, :auto_delete => true)
      @running = true

      @queue.subscribe(:ack => true) do |metadata, payload|
        DaemonKit.logger.debug "[requests] Workspace id #{payload}."
        EventMachine.synchrony do
          reply = workspace_state_reply payload

          @chan.default_exchange.publish(reply,
            :routing_key => metadata.reply_to,
            :correlation_id => metadata.message_id,
            :content_type => "application/json",
            :mandatory => true)
          metadata.ack
        end
      end

      return true
    end

    def stop
      if not @running
        DaemonKit.logger.error "Error: Workspace service is not started"
        return false
      end

      @queue.delete
      @chan.close
      @running = false
    end

    private
    def workspace_state_reply id
      nodes = {}

      VirtualMachine.find_all_by_workspace_id(id).each do |vm|
        nodes[vm.name] = vm.state
      end

      msg_dir = File.join(DaemonKit.root, "app", "messages")
      template = ERB.new File.new(File.join(msg_dir, "workspace_state.js.erb")).read
      return template.result(binding).split.join
    end
  end
end
