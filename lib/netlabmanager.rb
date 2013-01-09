# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

module NetlabManager
  @@tmp_l = []
  @@services = []

  def self.init_services
    DaemonKit.logger.debug "Loading services..."
    svc_dir = File.join(DaemonKit.root, "lib", "handlers")
    Dir[File.join(svc_dir, "*.rb")].each { |file| require file }
    @@tmp_l.each do |svc|
      DaemonKit.logger.debug "Starting service #{svc.class.name}"
      if svc.start
        @@services.push svc
      else
        DaemonKit.logger.warn "Service #{svc.class.name} could not be started"
      end
    end
    @@tmp_l.clear
  end

  def self.stop_services
    DaemonKit.logger.debug "Stop services..."
    @@services.each do |svc|
      DaemonKit.logger.debug "Stop service #{svc.class.name}"
      svc.stop
    end
  end

  def self.render(name, bind)
    msg_dir = File.join(DaemonKit.root, "app", "messages")
    template = ERB.new File.new(File.join(msg_dir, name)).read
    return template.result(bind).split.join(" ")
  end

  def self.add_handler handler
    @@tmp_l.push handler
  end

  class ServiceHandler
    def start
      #TODO: Implement in inherited class
    end

    def stop
      #TODO: Implement in inherited class
    end

    def self.inherited(klass)
      NetlabManager.add_handler klass.new
    end
  end
end
