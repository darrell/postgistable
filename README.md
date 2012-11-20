This is very much a work in progress. More to follow.

Requirements
============

* rake (duh)
* bundler
* sequel
* sequel-postgis (See: https://github.com/darrell/sequel-postgis)
* pg

If you want to use OSM data, you'll need osm2pgsql (http://wiki.openstreetmap.org/wiki/Osm2pgsql).

Obviously, you'll also need PostGIS, and if you plan to use OSM data, you may
need the hstore extension.These are not automatically loaded into the
database, so you'll need to that somewhere.

Usage
=====

First, you need to load the module, and configure it.

```ruby
require "rubygems"
require "bundler/setup" 
require 'postgistable'

Rake::TableTask::Config.dbname='your_database'
Rake::TableTask::Config.dbuser='your_username'
Rake::TableTask::Config.dbhost='dbhost.example.com'
Rake::TableTask::Config.dbpassword='5uper53kr1t'
Rake::TableTask::Config.dbport=5432
```

This module is dependent on the existence of a timestamp column, generally
"updated_at". For ease of use, we also define a trigger that keeps the
updated_at column, umm.. updated. This is because we don't presume that this
program is the only thing that will touch your data.

The import methods described below will automatically add the updated_at
column. If you are creating your own table, you need to be sure to add it, or
the task will always be executed (which may sometimes be what you want...)

Changes to the table are done with [Sequel]
(http://sequel.rubyforge.org/documentation.html). Generally speaking,
method_missing is used to call Sequel commands, first on the model, then on
the Sequel::Database. You can always access the Sequel::Postgres::Database
object via the #db method on the table task. See example below.

There *are* assumptions built into the various methods, but generally
assumptions that try to save time when "doing the right thing". For example,
if you add a timestamp column via the `add_update_column` method, the code
assumes you also want the trigger that keeps it updated.

I also try to make things idempotent. For instance, calling `add_update_column`
multiple times will not raise an error.

Here's a very basic example:

```ruby
table :my_table do |t|

  # create the table, unless it's already there.
  # to force drop/create, use `#create_table!` 
  # or explicitly drop the table with `#drop_table`
  t.create_table? do
    primary_key :gid
    String :name
    Time :updated_at
  end

  # add the column, and the trigger. Because we created
  # the updated_at column in create_table? above,
  # this will only add the trigger.
  t.add_update_column
  
  # because we're idempotent, this second call does nothing
  t.add_update_column
  
  # insert a row to our new table. (you probably won't do things
  # quite like this, but hey this is an example.
  #
  # we can do this by executing SQL directly:
  t.run %Q{INSERT INTO #{t.name}" (name) VALUES ('Bob Smith')}

  # or we can do it using Sequel syntax (`#ds` returns 
  # a Sequel::Dataset for this table)
  t.ds.insert(:name => 'Bob Smith')
  
  # Because this was meant for working with PostGIS, there are
  # also methods for dealing with that.
  
  # add a NAD83 point geometry column (defaults to SRID 4326)
  t.add_point_column :srid => 4269
  
  
end

```

Since this tool was designed with managing PostGIS data in mind, in addition
to the table task type, we also define a 'shapefile' task, which is smart
enough to check timestamps on all the various files that make up a shapefile.

The shapefile instance also includes the `#canonify` method, which renames all
the various components to be lowercase extensions. i.e. file.DBF becomes
file.dbf

```ruby
shapefile 'shps/roads.shp' do |t|
  t.canonify
end
```

There are a number of methods designed to help load various types of data, in
particular shapefiles, OSM data, and a Census TIGER specific method task type
that adds a few methods to Rake::TableTask that determine TIGER info from the
filename, then indexes and partitions the tables.

Loading a shapefile:

```ruby
shapefile 'shps/roads.shp'

table :my_roads => ['shps/roads.shp'] do |t|

  # load the shapefile roads.shp into the table "my_roads"
  # by default, the data is reprojected into WGS84 (SRID 4326).
  # this also creates indexes, and adds the updated_at column
  t.load_shapefile t.prerequisites.first
end
```

Loading data from OSM:

```ruby
# download the data
file 'osm/seattle.osm.bz2' do |t|
  %x{cd osm && wget --timestamping http://osm-metro-extracts.s3.amazonaws.com/seattle.osm.bz2}
end
# uncompress it
file 'osm/seattle.osm' => 'osm/seattle.osm.bz2' do |t|
  sh %Q{bzip2 -k -d osm/seattle.osm.bz2}
end

# load the OSM data. Unfortunately, osm2pgsql creates
# four tables out of each input file, so we
# need to make sure we get update columns on them all,
# but we only load the data once (in :seattle_osm_line)

table :seattle_osm_line => ['osm/seattle.osm'] do |t|
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

```

And, of course, tables can depend on other tables, and
be built from other tables.

```ruby
table :seattle_rails => [:seattle_osm_line] do |t|
  t.drop_table
  t.run %Q{
    SELECT osm_id as gid,railway,name,route_name,updated_at, way as the_geom 
      INTO #{t.name} 
      FROM "seattle_osm_line" 
      WHERE railway IS NOT NULL
  }

  t.add_update_column # add the trigger, even though we got the values from the parent.
  t.populate_geometry_columns # make sure PostGIS is happy
end
```

More Examples
=============

When we depend on multiple tables, we may want to make sure we get the most
recent "updated_at" so that we know if we need to update:

```ruby
table :my_table => [:table_one, :table_two] do |t|
  t.drop_table
  t.run %Q{
    INSERT INTO #{t.name} 
      SELECT table_one.*,table_two.name,
      -- always get the most recent updated_at for each_record
      -- so we know when to update this table if one of the deps changes
        greatest(table_one.updated_at,table_two.updated_at) 
      FROM table_one
        JOIN table_two ON (table_one.id=table_two.one_id)
  }
  # we don't add the update column trigger, because this table
  # should never be updated directly
end
```
---

Loads all shapefiles from the directory "shps" into tables of the same name
(e.g. "shps/roads.shp" becomes table "roads"):

```ruby

# find all the shapefiles
Dir['shps/**/*.[Ss][Hh][Pp]'].each do |shp|
  # define a task for each one, so we get the timestamps
  shapefile shp

  #  name the table
  table_name=File.basename(shp, '.shp')

  # define a task to drop the table, then reload the shapefile
  desc "load #{shp} into table #{table_name}"
  table table_name  do |t| => shp do |t|
    puts "loading #{table_name}"
    t.drop_table
    t.load_shapefile(shp) || t.drop_table
  end
end
```
---

This next example uses the tigertable task to load a complete set of tiger files.
It's made more challenging by the fact that TIGER files might be broken up
into many smaller files. We work around this by using partitioning and table
inheritance, putting state and county specific tables into their own schemas.

Parent tables all end up in the schema 'tiger'. Generally speaking, these
are the tables you want to query.

For example, if loading the tracts table for Oregon (FIPS code = 41) and
California (FIPS code = 06) we will create a number of schemas:

* tiger
* tiger_41
* tiger_06

The loader will then load each file into a county specific table, for
instance, tracts for Multnomah County, OR (FIPS code = 051) will be in
"tiger_41.tract051". 

tiger.tracts will then inherit that table. Check constraints are added
to each table on statefp and countyfp, so take advantage of them where possible.

Nation wide data files go into tiger_us.* and files which only exist on a
statewide basis (e.g. counties) go into single tables under the state-specific
FIPS code, e.g. "tiger_41.county".


```ruby
task :tiger do
  def load_tigerfiles(files)
   [files].flatten.each do |f|
      x=Rake::TableTask::TigerFile.new(f)
      task=tigertable "tiger_#{x.fips}__#{x.type}#{x.co_fips}".to_sym => f do |t|
        t.load_tigerfile
      end
      task.execute
      Rake::Task.clear
    end
  end

  # files with only a DBF
  # %w{ADDRFN ANRC CONCITY ESTATE FACESAH FACESAL FACESMIL FEATNAMES OTHERID SUBMCD UGA}.each do |x|
  %w{FACESAL FACESMIL FEATNAMES OTHERID SUBMCD UGA}.each do |x|
    # load_tigerfiles Dir["TIGER2012/#{x}/tl_2012_06*.dbf"]
    load_tigerfiles Dir["TIGER2012/#{x}/tl_2012_41*.dbf"]
  end
  # load_tigerfiles Dir['TIGER2012/**/tl_2012_06[0-9]*.shp']
  load_tigerfiles Dir['TIGER2012/**/tl_2012_*.shp']
end
```

TODOS
=====

* actually use tests
* many, many, things
* all tasks should probably be wrapped in a transaction
* make TIGER loading less ridiculous
* create osmtable task that incorporates all the tables created by osm2pgsql?
