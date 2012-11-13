
module Rake
  module TableTask
    class TigerFile
      include Rake::TableTask::PostGIS
      include Rake::TableTask::OGR
      include Rake::TableTask::OSM
      attr_reader :type, :fips, :year, :co_fips
      attr_reader :filename

      # takes the first file that matches a tiger-like filename
      def initialize(files)
        [files].flatten.each do |f|
          if f=~/tl_\d{4}_(us|\d\d)(\d{0,3})_(\w+)/
            @type=$3
            @fips=$1
            @co_fips=$2
            @co_fips=nil if @co_fips.empty?
            @filename=f
            return
          end
          raise ArgumentError, "could not find a matching tiger file in '#{f.inspect}'"
        end
      end

      def to_s
       @filename
      end
    end
    class TigerTableTask < Task

      attr_reader :source_file,:initialized

      def really_initialize
        return true if @initialized
        if prerequisites.empty?
          raise Rake::TaskArgumentError, "tigertable requires at least one prerequisite"
        end
        @source_file=Rake::TableTask::TigerFile.new(prerequisites)
        self.schema="tiger_#{source_file.fips}"
        @initialized=true
      end

      def source_file
        @source_file||=Rake::TableTask::TigerFile.new(prerequisites)
      end

      def source_file=(x)
        @source_file = x
      end

      def needed? #:nodoc:
        # have to abuse needed? to do some initialization
        # because I don't have access to prereqs during initalize()
        really_initialize
        super
      end

      def create_schema(name)
        begin
          db.create_schema name
        rescue Sequel::DatabaseError => err
          raise err unless err.message =~ /schema "#{name}" already exists/
        end
      end
      # load a shp or dbf file from the prerequisites
      # the first prerequisite that matches a tiger filename
      # will be the one loaded.
      def load_tigerfile(opts={})
        create_schema self.schema_name
        load_shapefile self.source_file.filename, :append => true

        # create indexes, but ignore errors for missing
        # columns. Makes it easier to generate a big set of defaults

        tiger_indexes(self.source_file).each do |col|
          begin
            add_index col
          rescue => err
            raise unless err.message =~ /column "#{col}" does not exist/
          end
        end

        if source_file.fips =~ /^\d\d$/ and model.columns.map{|x|x.to_sym}.include? :statefp
          fips=source_file.fips
          begin
            db.alter_table(model.table_name) do
              add_constraint :check_statefp,:statefp => fips
            end
          rescue => e
            raise unless e.message =~ /constraint.*already exists/
          end
        end
        configure_inheritance
      end
      
      
      private
      def configure_inheritance
        create_schema 'tiger'
        # no way to do this using the Sequel DSL (at least that I can see)
        if !db.table_exists? "tiger__#{table_name}".to_sym
          db.run %Q{CREATE TABLE "tiger".#{table_name} (LIKE #{model.simple_table})}
        end
        begin
          db.run %Q{ALTER TABLE #{model.simple_table} INHERIT "tiger".#{table_name}}
        rescue => err
          raise unless err.message =~ /would be inherited from more than once/
        end
      end

      def tiger_indexes(f)
        # take a file type (tract, edges, etc) in case we want to alter
        # these in the future. But for now, just return everything
        [:statefp, :geoid, :name, :tlid , :tfidl, :tfidr, :countyfp, :zipl, :zipr]
      end
    end
  end
end

def tigertable(*args, &block)
  Rake::TableTask::TigerTableTask.define_task(*args, &block)
end