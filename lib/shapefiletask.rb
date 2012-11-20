require 'rake'
require 'pathname'

# requires gdal >= 1.8.0 for PGdump support
# http://www.gdal.org/ogr/drv_pgdump.html
# ogr2ogr -f PGDump /dev/stdout jason/bathymetry_poly.shp|less
module Rake
  class ShapeFileTask < FileTask

    def initialize(*args, &block)
      super(*args, &block)
      @shpname=args.first
      @shpname_base=[File.dirname(@shpname),File.basename(@shpname, '.shp')].join('/')
      @shp_extentions=%w{shx dbf prj sbn fbn fbx ain aih ixs mxs atx shp.xml}

      # we want to always touch the .shp if any of the components have changed,
      # otherwise we'll just run over and over again. 
      # but this can bite us, since it's done first, right?
      enhance(find_components) do |x|
        FileUtils.touch x.name
      end
    end

    def find_components()
      #extensions: .shp .shx .dbf .prj .sbn .fbn .fbx .ain .aih .ixs .mxs .atx .shp.xml
      # all shapefiles must have at least shp, dbf, shx
      b=File.basename @shpname_base
      mydir=File.dirname(@shpname)
      components=[]
      Dir.foreach(mydir) do |i|
        components.push(Pathname.new("#{mydir}/#{i}")) if /^#{b}\.(#{@shp_extentions.join('|')})/i.match(i)
      end
      len=components.grep(/\.(shx|dbf)$/i).length
      # puts components.grep(/\.(shx|dbf)$/i)
      # raise "shapefile '#{@shpname}' is missing a component. Found #{len} components: #{components.join(' ')}" unless len==2
      return components
    end 

    def canonify_components
      canonify
    end

    # downcase all the constituent parts
    # of a shapefile so they match.
    def canonify
      find_components.each do |comp|
        # set the newname
        newext=/\.shp\.xml$/i.match(comp.to_s.downcase)
        if newext.nil? then
          newext=comp.extname.downcase
        end
        newname="#{@shpname_base}#{newext}"
        oldname=comp.to_s
        begin
          if oldname != newname then
            puts "renaming #{oldname} to #{newname}"
            File.rename oldname, newname
          end
        end
      end
      find_components # update with new filenames and return list
    end

  end #class ShapeFileTask
end # module Rake

def shapefile(*args, &block)
  Rake::ShapeFileTask.define_task(*args, &block)
end