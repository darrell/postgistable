$: << File.expand_path(File.dirname(__FILE__) + "/lib/")
$: << File.expand_path(File.dirname(__FILE__) + "/rake/")
require "rubygems"
# The part that activates bundler in your app:
require "bundler/setup" 
# require your gems as usual
#require "some_gem"

require 'tabletask'
require 'shapefiletask'


Dir['**/*.[Ss][Hh][Pp]'].each do |shp|
  shapefile shp
end

shps=Dir['shps/**/*.[Ss][Hh][Pp]']
tables=[]
shps.each do |shp|
  # shapefile shp
  shapefile shp
  table_name=File.basename(shp, '.shp')
  tables.push(table_name)
  desc "load #{shp} into table #{table_name}"
  table table_name  do |t| #=> shp do |t|
    puts "loading #{table_name}"
    t.load_shapefile(shp) || t.drop_table
  end
end

task :default => tables

file 'osm/seattle.osm.pbf' do |t|
  sh %Q{cd osm && wget --timestamping http://osm-metro-extracts.s3.amazonaws.com/seattle.osm.pbf}
end

file 'osm/seattle.osm' => 'osm/seattle.osm.bz2' do |t|
  sh %Q{bzip2 -k -d osm/seattle.osm.bz2}
end

file 'osm/seattle.osm.bz2' do |t|
  %x{cd osm && wget --timestamping http://osm-metro-extracts.s3.amazonaws.com/seattle.osm.bz2}
end

file 'osm/default.style'

table :world => 'shps/world.shp' do |t|
  t.load_shapefile t.prerequisites.first
end

table :seattle_osm_line => ['osm/default.style','osm/seattle.osm'] do |t|
  t.load_osmfile('osm/seattle.osm', :style => 'osm/default.style')
  t.add_update_column
end
table :seattle_osm_point => :seattle_osm_line do |t|
  t.add_update_column
end
table :seattle_osm_polygon => :seattle_osm_line do |t|
  t.add_update_column
end
table :seattle_osm_roads  => :seattle_osm_line do |t|
  t.add_update_column
end

task :seattle_osm => [:seattle_osm_roads, :seattle_osm_polygon, :seattle_osm_point, :seattle_osm_line ]

table :seattle_rails => [:seattle_osm] do |t|
  t.drop_table
  t.run %Q/
    SELECT osm_id as gid,railway,name,route_name,updated_at, way as the_geom 
      INTO #{t.table_name_literal} 
      FROM "seattle_osm_line" 
      WHERE railway IS NOT NULL/
  t.add_update_column
  t.populate_geometry_columns
end
