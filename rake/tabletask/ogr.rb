module Rake
  class TableTask < Task
    def load_shapefile(shp, options = {})
      options[:srid]||=4326
      ENV['PGCLIENTENCODING']='LATIN1'
      if @as_geography
        geom_column=geography_column
        geom_type="geography"
      else
        geom_column=geometry_column
        geom_type="geometry"
      end
        #-explodecollections \
      sh %Q{
        ogr2ogr -f PostgreSQL PG:dbname="#{Config.dbname}" \
        -overwrite \
        -t_srs  EPSG:#{options[:srid]} \
        --config PG_USE_COPY #{@use_copy.to_s} \
        -nlt MULTIPOLYGON \
        -lco FID=#{primary_key} \
        -lco PRECISION=NO \
        -lco GEOMETRY_NAME="#{geom_column}"\
        -lco GEOM_TYPE="#{geom_type}" \
          "#{shp}" -nln "#{table_name}"
      }
      add_updated_at
    end
  end
end
