class Workspace < NetlabManager::ServiceHandler
  def initialize
    @chan = AMQP::Channel.new
    @queue = @chan.queue("netlab.services.workspace.state", :exclusive => true, :auto_delete => true)
    @initialized = true
  end

  def start
    #TODO: Implement this
  end

  def stop
    #TODO: Implement this
  end
end
