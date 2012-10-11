module Rake
  class TableTask < Task
    include Rake::DSL
    def load_osmfile(osm, options = {})
      options[:srid]||=4326
      options[:with_hstore]||=true
      options[:style]||=nil
      prefix=table_name.to_s.sub(/_(line|point|polygon|roads)$/,'')
      puts prefix
      # if @as_geography
      #   geom_column=geography_column
      #   geom_type="geography"
      # else
      #   geom_column=geometry_column
      #   geom_type="geometry"
      # end
      sh %Q{
        osm2pgsql --multi-geometry \
         -d "#{Config.dbname}"\
         -p #{prefix} \
         --slim \
         -E #{options[:srid]} \
         --extra-attributes \
         --drop \
         #{options[:with_hstore] ? "--hstore-all" : ''} \
         #{options[:style] ? "--style '#{options[:style]}'" : ''} \
         --number-processes 2 \
         #{osm}
      }
    end
  end
end
