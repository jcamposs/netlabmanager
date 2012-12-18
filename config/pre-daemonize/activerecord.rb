begin
  require 'em-synchrony/activerecord'
rescue LoadError
  $stderr.puts "Missing em-synchrony gem. Please run 'bundle install'."
  exit 1
end

#TODO: load models
