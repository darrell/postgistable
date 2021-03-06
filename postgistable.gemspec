Gem::Specification.new do |s|
  s.name        = 'postgistable'
  s.version     = '0.1.0'
  s.summary     = "Rake task type for managing PostGIS tables"
  s.authors     = ["Darrell Fuhriman"]
  s.email       = 'darrell@garnix.org'
  s.files       = Dir['lib/**']
  %w{pg sequel sequel-postgis rake}.each do |g|
    s.add_runtime_dependency g
  end
end
