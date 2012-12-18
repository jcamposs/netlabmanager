class VirtualMachine < ActiveRecord::Base
end

class Workspace < NetlabManager::ServiceHandler
  def start
    @chan = AMQP::Channel.new
    @queue = @chan.queue("netlab.services.workspace.state", :exclusive => true, :auto_delete => true)
    @running = true

    @queue.subscribe(:ack => true) do |metadata, payload|
      DaemonKit.logger.debug "[requests] Workspace id #{payload}."
      EventMachine.synchrony do
        reply = get_workspace payload

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
      DaemonKit.logger.error "Error: Workspace class is not started"
      return false
    end

    @queue.delete
    @chan.close
    @running = false
  end

  private
  def compose_json_reply(nodes, id)
    obj = {
      "workspace" => id,
      "nodes" => []
    }

    nodes.keys.each do |name|
      obj["nodes"].push({
        "name" => name,
        "state" => nodes[name]
      })
    end

    return obj.to_json
  end

  def get_workspace id
    nodes = {}
    VirtualMachine.find_all_by_workspace_id(id).each do |vm|
      nodes[vm.name] = vm.state
    end

    compose_json_reply(nodes, id)
  end
end
