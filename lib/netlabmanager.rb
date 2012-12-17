# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

module NetlabManager
  @@handlers = []

  def self.init_services
    svc_dir = File.join(DaemonKit.root, "lib", "handlers")
    Dir[File.join(svc_dir, "*.rb")].each { |file| require file }
    @@handlers.each do |handler|
      DaemonKit.logger.debug "Start handler #{handler.class.name}"
      handler.stop
    end
  end

  def self.stop_services
    @@handlers.each do |handler|
      DaemonKit.logger.debug "Stop handler #{handler.class.name}"
      handler.stop
    end
  end

  def self.add_handler handler
    @@handlers.push handler
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
