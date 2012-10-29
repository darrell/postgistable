class TigerFile
  attr_reader :type, :fips, :year, :co_fips
  attr_reader :filename

  def initialize(f)
    @orig = f
    if f=~/tl_\d{4}_(us|\d\d)(\d{0,3})_(\w+)/
      @type=$3
      @fips=$1
      @co_fips=$2
      @co_fips=nil if @co_fips.empty?
    end
  end

  def to_s
    @filename
  end

end

module Rake
  class TableTask < Task

    def load_tigerfile(file, opts={})
      f=TigerFile.new(file)
      self.send("load_tigerfile_#{f.type}", f)
    end
    
    def load_tigerfile_tract(f)
      self.load_shapefile f.filename
      self.add_index :statefp
    end
  end
end