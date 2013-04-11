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

      #Request queues:
      init_connect_svc

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
              send_shellinabox_notif(shell)
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

    def send_shellinabox_notif(shell)
      if not shell
        DaemonKit.logger.error "Error: No shellinabox instance"
      elsif shell.port_number < 0 or not shell.host_name
        DaemonKit.logger.error "Error: Shellinabox process is not started yet"
      else
        DaemonKit.logger.debug "Send shellinabox notification"
      end
    end
  end
end
