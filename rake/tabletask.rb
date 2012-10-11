require 'rubygems'
require 'date'
require 'rake'
require 'boolean_attributable'
require 'pg'
require 'active_record'
require 'sequel'
# require 'sequel/postgis'
require 'tabletask/postgis'
require 'tabletask/ogr'
require 'tabletask/osm'
require 'logger'
# require 'sequel/extensions/string_date_time'

# require 'active_record/connection_adapters/postgis_adapter/railtie'
 
module Rake
  class TableTask < Task
    extend BooleanAttributable
    class Config
      attr_accessor :model, :dbname, :dbuser
      @@dbname='gis'
      @@dbuser='darrell'
      def self.dbname
        @@dbname
      end
      def self.dbuser
        @@dbuser
      end
      
    end
    
    def connect_to_db(db = 'gis')
       # conn=PGconn.connect( :dbname   => db)
       # @@db=conn
       @@db = Sequel.postgres(db)
       # @@db=ActiveRecord::Base.establish_connection(:adapter => 'postgis',:dbname   => db)
        # conn.exec 'set log_duration=off'
        # conn.exec 'set search_path=public,tiger'
       if Rake.application.options.trace
         DB.loggers << Logger.new($stdout)
         # conn.exec('set client_min_messages to debug')
       else
         # conn.exec('set client_min_messages to error')
      end
       return @@db
     end

    
    attr_accessor :geometry_column, :geography_column, :id_column, :srid
    attr_reader :model, :dbname, :dbuser
    boolean_attr :use_copy, :as_geography
    
    @@db=Sequel.connect("postgres:/#{Config.dbname}")
    Sequel::Model.plugin :postgis
    def initialize(*args, &block)
      super(*args, &block)
      if Rake.application.options.trace
        @@db.loggers << ::Logger.new($stdout)
      end
      @use_copy = true
      @geometry_column = :the_geom
      @geography_column = :the_geog
      @id_column = :gid
      @as_geography = false
      @srid=4326
      
      #class_eval
      @model = Class.new(Sequel::Model(name.to_sym))
      @model.set_primary_key @id_column

      # connect_to_db
      ActiveRecord::Base.establish_connection(:adapter => 'postgis',:database   => Config.dbname)
      # @ar_model = Class.new(ActiveRecord::Base)
      # 
      # 
      # @ar_model.table_name = name
      # @ar_model.set_primary_key @id_column
    end

    # if it's not defined here, try it on the Sequel Model
    def method_missing(name, *args)
      begin
        @model.send(name, *args)
      rescue NoMethodError
        @model.db.send(name, *args)
      end
    end

    ###############
    ##
    ## Rake-related tasks
    ##
    ###############
    
    def needed? #:nodoc:
      return true if not exists?
      ts=timestamp
      return true if ts.nil?
      return true if out_of_date?(ts)
    end

    # has the table been created?
    def exists?
      return true
      begin
        res=@@db.fetch %Q/ SELECT tablename FROM pg_tables WHERE tablename=?/, table_name
        if res.count == 0
          res=@@db.fetch %Q/ SELECT viewname FROM pg_views WHERE viewname=?/, table_name
        end
      rescue => err
        return false
      end
      if res.count > 0
        return true
      end
      return false
    end

    # return the last time this table was updated
    # if we get an error, perhaps because the updated_at
    # column does not exist, then return Rake::EARLY
    def timestamp
      begin
        max=@model.max(:updated_at)
      rescue => err
        # puts " error was #{err}"
        # if we get an error, just assume we need to update the table
        return Rake::EARLY
      end
      # this is embarassing, but rake doesn't have a way to say
      # that this thing is more recently updated than anything else
      max.nil? ? Time.parse('Dec 31, 9999') : max
    end

    # private

    # Are there any prerequisites with a later time than the given time stamp?
    def out_of_date?(stamp)
      return true if stamp.is_a? Rake::EarlyTime
      @prerequisites.any? { |n| application[n].timestamp > stamp}
    end

    class << self
      # Apply the scope to the task name according to the rules for this kind
      # of task.  File based tasks ignore the scope when creating the name.
      def scope_name(scope, task_name)
        task_name
      end
    end


    def table_name
      name.to_sym
    end

    def table_name_literal
      @@db.literal(table_name)
    end

    # will this task use insert instead of copy when loading a shapefile?
    # --
    # it's opposites day!
    def use_insert?
      !use_copy?
    end

    # force task to use
    def use_insert!
      @use_copy = false
    end
    
    def use_insert=(x)
      @use_copy = x ? false : true
    end
    
    # def primary_key
    #   @model.primary_key
    # end
    # 
    # def table_name
    #   @model.table_name
    # end
    
    def run(*args)
      puts "running #{args.inspect}"
      db.transaction do
        db.run *args
      end
    end
    
    def create_table(*args, &block)
      db.create_table!(name,*args, &block)
      unless primary_key_exists?
        add_primary_key
      end
    end

    def drop_table
      puts db.table_exists?(name)
      db.drop_table(name) if db.table_exists?(name)
    end

    def ds
      dataset
    end

    def dataset
       @@db.from(name)
    end   

    def add_primary_key
      pk=primary_key
      @@db.alter_table(name) do
        add_primary_key pk
      end
    end
    
    def primary_key_exists?
      @model.columns.include? primary_key
    end
  end
end

def table(*args, &block)
  Rake::TableTask.define_task(*args, &block)
end
