Dir[File.expand_path("#{File.dirname(__FILE__)}/rasm/*.rb")].each do |file|
  require file
end
