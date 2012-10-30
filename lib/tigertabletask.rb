
module Rake
  class TigerFile
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

  class TigerTableTask < TableTask

    attr_reader :source_file,:initialized

    def really_initialize
      return true if @initialized
      if prerequisites.empty?
        raise Rake::TaskArgumentError, "tigertable requires at least one prerequisite"
      end
      @source_file=TigerFile.new(prerequisites)
      self.schema="tiger_#{source_file.fips}"
      @initialized=true
    end

    def needed? #:nodoc:
      # have to abuse needed? to do some initialization
      # because I don't have access to prereqs during initalize()
      really_initialize
      super
    end

    # load a shp or dbf file from the prerequisites
    # the first prerequisite that matches a tiger filename
    # will be the one loaded.
    def load_tigerfile(opts={})
      begin
        db.create_schema self.schema_name
      rescue Sequel::DatabaseError => err
        raise err unless err.message =~ /schema "#{self.schema_name}" already exists/
      end
      load_shapefile source_file.filename
      add_index tiger_indexes(self.source_file)
      if source_file.fips =~ /^\d\d$/
        fips=source_file.fips
        db.alter_table(model.table_name) do
          add_constraint :check_statefp,:statefp => fips
        end
      end
      
    end
    
    private

    def tiger_indexes(f)
      # common=[:statefp, :placefp, :countyfp, :cousubfp, :name, :street, :fullstreet, :arid, :tlid, :linearid, :fullname, :tfidl, :tfidr]
      common=[:statefp,:name, :geoid]
      case f.type
      when 'tract'
        common+[ :countyfp ]
      when 'state'
        common
      else
        []
      end
    end
  end
end
def tigertable(*args, &block)
  Rake::TigerTableTask.define_task(*args, &block)
end