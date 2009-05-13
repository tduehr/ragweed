Dir[File.expand_path("#{File.dirname(__FILE__)}/wrap32/*.rb")].each do |file|
  require file
end
