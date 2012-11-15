module Rake
  module TableTask
    class Config
      class <<self
        attr_accessor :dbname, :dbuser, :dbhost,:dbpassword,:dbport
        def initialize(options={})
          @dbuser ||= options[:dbuser]
          @dbname ||= options[:dbname]
          @dbpassword ||= options[:dbpassword]
          @dbport ||= options[:dbport]
          @dbhost ||= options[:dbhost]
        end
      end

      def self.sequel_connect_string
        str='postgres://'
        str+=@dbuser if @dbuser
        str+=':'+@dbpassword if @dbpassword
        str+='@' + @dbhost if @dbhost
        str+='/'+@dbname if @dbname
        str
      end

      def self.ogr_connect_string
        str='PG: '
        str+=' dbname='+@dbname if @dbname
        str+=' user='+@dbuser if @dbuser
        str+=' password='+@dbpassword if @dbpassword
        str+=' host=' + @dbhost if @dbhost
        str
      end
    end
  end
end