begin
  require 'em-synchrony/activerecord'
rescue LoadError
  $stderr.puts "Missing em-synchrony gem. Please run 'bundle install'."
  exit 1
end

# load models
models_dir = File.join(DaemonKit.root, "app", "models")
Dir[File.join(models_dir, "*.rb")].each { |file| require file }
