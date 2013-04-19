module NetlabEvent
  @@events = {}

  def self.on(event, &block)
    @@events[event] = [] if not @@events[event]
    @@events[event].push(block)
  end

  def self.emit(event, *args)
    return if not @@events[event]

    @@events[event].each do |block|
      block.call(args)
    end
  end
end
