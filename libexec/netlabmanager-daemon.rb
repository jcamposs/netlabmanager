# Generated amqp daemon

# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
DaemonKit::Application.running! do |config|
  config.trap( 'INT' ) { NetlabManager.stop_services }
  config.trap( 'TERM' ) { NetlabManager.stop_services }
end

# IMPORTANT CONFIGURATION NOTE
#
# Please review and update 'config/amqp.yml' accordingly or this
# daemon won't work as advertised.

# Run an event-loop for processing
DaemonKit::AMQP.run do |connection|
  # Inside this block we're running inside the reactor setup by the
  # amqp gem. Any code in the examples (from the gem) would work just
  # fine here.

  # Uncomment this for connection keep-alive
  # connection.on_tcp_connection_loss do |client, settings|
  #   DaemonKit.logger.debug("AMQP connection status changed: #{status}")
  #   client.reconnect(false, 1)
  # end

  NetlabManager.init_services

  amq = AMQP::Channel.new
  amq.queue('test').subscribe do |msg|
    DaemonKit.logger.debug "Received message: #{msg.inspect}"
  end
end
