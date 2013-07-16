module Rake
  module TableTask
    module OGR
      def load_shapefile(shp, options = {})
        options[:srid]||=4326
        options[:schema]||='public'
        
        # append_or_overwrite= fetch(options[:append], false) ? '-append' : '-overwrite'
        append_or_overwrite= '-overwrite'
        ENV['PGCLIENTENCODING']='LATIN1'
        if @as_geography
          geom_column=geography_column
          geom_type="geography"
        else
          geom_column=geometry_column
          geom_type="geometry"
        end
        srs=shp =~ /\.shp$/ ? "-t_srs  EPSG:#{options[:srid]}" : ''
          #-explodecollections \
        sh %Q{
          ogr2ogr -f PostgreSQL "#{Config.ogr_connect_string}" \
          #{append_or_overwrite} \
          --config PG_USE_COPY #{@use_copy.to_s} \
          #{srs} \
          -lco FID=#{primary_key} \
          -lco PRECISION=NO \
          -nlt #{shapefile_geom(shp)} \
          -lco GEOMETRY_NAME="#{geom_column}"\
          -lco GEOM_TYPE="#{geom_type}" \
            "#{shp}" -nln #{simple_table}
        }
        model.add_update_column
      end
      #returns the geometry of a given shapefile
      # NONE, GEOMETRY, POINT, LINESTRING, POLYGON, GEOMETRYCOLLECTION, MULTIPOINT, MULTIPOLYGON or MULTILINESTRING
      def shapefile_geom(shp)
        str=%x{ ogrinfo -q #{shp}}
        str.sub!(/\b3D\b/i,'')
        if str =~ /1:.*\((.*)\)/
          return $1.gsub(' ','').upcase
        end
      end
    end
  end
end
