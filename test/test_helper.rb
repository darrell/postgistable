$: << File.expand_path(File.dirname(__FILE__) + "/../lib/")
$: << File.expand_path(File.dirname(__FILE__) + "/../rake/")
require 'rubygems'
require 'test/unit'
require 'sequel'

class PostGisTestCase < Test::Unit::TestCase
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always){result = super}
    result
  end
  def dummy_table do
    Sequel::Model
  end

end
