require 'netlabevent'

module NetlabHandler
  class ShellinaboxHandler < NetlabManager::ServiceHandler
    def start
      init_amqp_stuff
      @running = true
      NetlabEvent.on "vm closed" do |id|
        # TODO: Stop all shellinaboxes associated with this virtual machine
      end
      return true
    end

    def stop
      shutdown_amqp_stuff
    end

    private
    def init_amqp_stuff
      @chan = AMQP::Channel.new
      @chan.auto_recovery = true

      #Request queues:
      init_connect_svc
      init_disconnect_svc

      #Event queues:
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

    def init_connect_svc
      queue_name = "#{DAEMON_CONF[:root_service]}.shellinabox.connect"
      @connect_queue = @chan.queue(queue_name, :durable => true)
      @connect_queue.subscribe() do |metadata, payload|
        DaemonKit.logger.debug "[requests] Connect Shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          EventMachine.synchrony do
            shell = get_shellinabox(req)
            if shell
              send_connected_shellinabox_notif(shell)
            else
              shell = create_shellinabox(req)
              send_create_shellinabox_req(shell)
            end
          end
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end

    def init_disconnect_svc
      queue_name = "#{DAEMON_CONF[:root_service]}.shellinabox.disconnect"
      @disconnect_queue = @chan.queue(queue_name, :durable => true)
      @disconnect_queue.subscribe() do |metadata, payload|
        begin
          req = JSON.parse(payload)
          EventMachine.synchrony do
            shell = get_shellinabox(req)
            if shell
              destroy_shellinabox(shell)
            else
              send_disconnected_shellinabox_notif(req)
            end
          end
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
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
        send_connected_shellinabox_notif(shell)
      rescue Exception => e
        DaemonKit.logger.error e.message
        DaemonKit.logger.error e.backtrace
      end
    end

    def uptade_stopped_daemon(msg)
      msg["shellinaboxes"].each do |id|
        begin
          shell = Shellinabox.find(id)
          if shell.host_name == msg["host_name"]
            destroy_shellinabox_instance(shell)
          end
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end

    def get_shellinabox(req)
      vm = VirtualMachine.find_by_workspace_id_and_name(req["workspace"],
                                                                    req["node"])
      return null if not vm

      shell = Shellinabox.find_by_virtual_machine_id_and_user_id(vm.id,
                                                                    req["user"])

      return shell
    end

    def create_shellinabox(req)
      vm = VirtualMachine.find_by_workspace_id_and_name(req["workspace"],
                                                                    req["node"])

      return nil if not vm

      shell = Shellinabox.new
      shell.user_id = req["user"]
      shell.virtual_machine_id = vm.id
      shell.save

      return shell
    end

    def send_create_shellinabox_req(shell)
      if not shell
        DaemonKit.logger.error "Error: Unable to create shell process"
        return
      end

      req = {
        "id" => shell.id,
        "user_id" => shell.user_id,
        "vm_port" => shell.virtual_machine.port_number,
        "vm_proxy" => shell.virtual_machine.workspace.proxy
      }

      rkey = "shellmanager.#{DaemonKit.env}.start"

      @chan.default_exchange.publish(req.to_json, {
        :routing_key => rkey,
        :content_type => "application/json"}
      )
    end

    def destroy_shellinabox_instance(shell)
      data = {
        "workspace" => shell.virtual_machine.workspace.id,
        "node" => shell.virtual_machine.name,
        "user" => shell.user_id
      }
      send_disconnected_shellinabox_notif(data)
      shell.destroy
    end

    def send_destroy_shellinabox_req(shell)
      msg = { "id" => shell.id }
      ex = @chan.fanout("shellmanager.#{DaemonKit.env}.stop")
      ex.publish(msg.to_json, {:content_type => "application/json"})
    end

    def destroy_shellinabox(shell)
      if not shell
        DaemonKit.logger.error "Error: No shellinabox instance"
      elsif shell.port_number < 0 or not shell.host_name
        destroy_shellinabox_instance(shell)
      else
        send_destroy_shellinabox_req(shell)
      end
    end

    def send_connected_shellinabox_notif(shell)
      if not shell
        DaemonKit.logger.error "Error: No shellinabox instance"
      elsif shell.port_number < 0 or not shell.host_name
        DaemonKit.logger.error "Error: Shellinabox process is not started yet"
      else
        workspace = shell.virtual_machine.workspace.id
        event = {
          "workspace" => workspace,
          "type" => "shell",
          "node" => shell.virtual_machine.name,
          "state" => "connected",
          "user" => shell.user_id,
          "host" => shell.host_name,
          "port" => shell.port_number
        }

        ex = @chan.direct("#{DAEMON_CONF[:root_event]}.workspace.#{workspace}")
        ex.publish(event.to_json, {:content_type => "application/json"}) do
          DaemonKit.logger.debug("<< #{event.to_json}")
        end
      end
    end

    def send_disconnected_shellinabox_notif(req)
      workspace = req['workspace']

      event = {
        "workspace" => workspace,
        "type" => "shell",
        "node" => req["node"],
        "state" => "disconnected",
        "user" => req["user"]
      }

      ex = @chan.direct("#{DAEMON_CONF[:root_event]}.workspace.#{workspace}")
      ex.publish(event.to_json, {:content_type => "application/json"}) do
        DaemonKit.logger.debug("<< #{event.to_json}")
      end
    end
  end
end
