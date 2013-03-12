module NetlabHandler
  class WorkspaceHandler < NetlabManager::ServiceHandler
    def start
      @chan = AMQP::Channel.new

      init_state_svc
      init_update_svc

      @running = true
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
    def init_state_svc
      queue_name = "#{DAEMON_CONF[:root_service]}.workspace.state"
      @queue = @chan.queue(queue_name, :durable => true)

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
    end

    def init_update_svc
      queue_name = "#{DAEMON_CONF[:root_service]}.workspace.update"
      @update_queue = @chan.queue(queue_name, :durable => true)
      @update_queue.subscribe() do |metadata, payload|
        DaemonKit.logger.debug "[requests] Workspace Update #{payload}."
        begin
          req = JSON.parse(payload)
          EventMachine.synchrony do
            nodes =  uptade_workspace(req)
            send_update_notif(req["workspace"], nodes) if nodes.length > 0
          end
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end

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

    def send_update_notif(workspace, nodes)
      event = {
        "workspace" => workspace,
        "nodes" => nodes
      }

      ex = @chan.direct("#{DAEMON_CONF[:root_event]}.workspace.#{workspace}")
      ex.publish(event.to_json, {:content_type => "application/json"}) do
        DaemonKit.logger.debug("<< #{event.to_json}")
      end
    end

    def uptade_workspace(msg)
      nodes = []

      VirtualMachine.transaction do
        msg["nodes"].each do |node|
          vm = VirtualMachine.find_by_workspace_id_and_name(msg["workspace"],
                                                                   node["name"])
          if vm and vm.state != node["state"]
            vm.state = node["state"]
            if vm.state == "started"
              vm.port_number = node["port"]
            else
              vm.port_number = -1
            end
            vm.save
            nodes.push({
              "name" => vm.name,
              "state" => vm.state
            })
          end
        end
      end

      return nodes
    end
  end
end
