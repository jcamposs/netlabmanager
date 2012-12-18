begin
  require 'mysql2'
rescue LoadError
  $stderr.puts "Missing mysql2 gem. Please run 'bundle install'."
  exit 1
end
