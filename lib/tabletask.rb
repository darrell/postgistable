require 'rubygems'
require 'date'
require 'rake'
require 'boolean_attributable'
require 'pg'
require 'sequel'
# require 'sequel/postgis'
require 'tabletask/config'
require 'tabletask/postgis'
require 'tabletask/ogr'
require 'tabletask/osm'
require 'tabletask/tiger'
require 'logger'

# require 'sequel/extensions/string_date_time'

# require 'active_record/connection_adapters/postgis_adapter/railtie'
 
module Rake
  module TableTask
    class Task < Rake::Task

    extend BooleanAttributable
    include Rake::TableTask::PostGIS
    include Rake::TableTask::OGR
    include Rake::TableTask::OSM

    attr_accessor :geometry_column, :geography_column, :id_column, :srid,:db
    attr_reader :model, :dbname, :dbuser
    boolean_attr :use_copy, :as_geography
    

    def initialize(*args, &block)
      super(*args, &block)
      @db=Sequel.connect(Config.sequel_connect_string)
      @db.cache_schema=false
      Sequel::Model.plugin :postgis
      @db.extension :postgis

      if Rake.application.options.trace
        @db.loggers << ::Logger.new($stdout)
        @db.run('set client_min_messages to debug')
      else
        @db.run('set client_min_messages to error')
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
      begin
        res=@db.fetch %Q/ SELECT tablename FROM pg_tables WHERE tablename='%s' AND schemaname='%s'/ % [table_name,schema_name]
        if res.count == 0
          res=@db.fetch %Q/ SELECT viewname FROM pg_views WHERE viewname='%s'AND schemaname='%s'/ % [table_name,schema_name]
        end
      rescue PG::Error => err
        return false
      end
      return res.count > 0
    end

    # return the last time this table was updated
    # if we get an error, perhaps because the updated_at
    # column does not exist, then return Rake::EARLY
    def timestamp
      begin
        max=model.max(:updated_at)
      #rescue PG::Error => err
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
      model.dataset.schema_and_table(model.table_name)[1]
    end
    
    def table_name_and_schema
      model.dataset.schema_and_table(model.table_name)
    end

    def table_name_literal
      @db.literal(table_name)
    end
    
    def table_name=(name)
      puts "settings schema to #{name}"
      model.dataset=name
    end
    
    def schema_name
      model.dataset.schema_and_table(model.table_name)[0] || 'public'
    end
      
    def schema=(name)
      if schema_name != name
        self.table_name="#{name}__#{table_name}".to_sym
      end
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

    def truncate!
      db[model.table_name].truncate
    end

    def drop_table
      db.drop_table(model.table_name) if db.table_exists?(model.table_name)
    end

    def indexed_columns
      cols=[]
      db.indexes(model.table_name).each do |k,v|
        if v[:columns].length == 1
          cols << v[:columns][0]
        else
          cols << v[:columns]
        end
      end
      cols.uniq
    end
    def add_index(idxs, opts={})
      # do not index columns that have indexes
      if ! idxs.is_a? Enumerable
        idxs=[idxs].flatten
      end
      idxs=idxs-indexed_columns
      return true if idxs.empty?
      db.alter_table(model.table_name) do
        idxs.each do |i|
          add_index i, opts
        end
      end
    end

    def ds
      dataset
    end

    def dataset
       @db.from(name)
    end   

    def add_primary_key
      pk=primary_key
      db.alter_table(name) do
        add_primary_key pk
      end
    end
    
    def primary_key_exists?
      model.columns.include? primary_key
    end
  end
end
end

def table(*args, &block)
  Rake::TableTask::Task.define_task(*args, &block)
end
