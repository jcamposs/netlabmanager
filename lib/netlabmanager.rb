# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

module NetlabManager
  @@services = []

  def self.init_services
    DaemonKit.logger.debug "Loading services..."
    svc_dir = File.join(DaemonKit.root, "lib", "handlers")
    Dir[File.join(svc_dir, "*.rb")].each { |file| require file }
    @@services.each do |handler|
      DaemonKit.logger.debug "Starting service #{handler.class.name}"
      handler.start
    end
  end

  def self.stop_services
    DaemonKit.logger.debug "Stop services..."
    @@services.each do |handler|
      DaemonKit.logger.debug "Stop service #{handler.class.name}"
      handler.stop
    end
  end

  def self.add_handler service
    @@services.push service
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
