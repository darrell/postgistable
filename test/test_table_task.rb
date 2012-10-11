require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class TableTask < Rake::TableTask
end

class TestTableTask < Test::Unit::TestCase
  def setup
    @rake = Rake::Application.new
    Rake.application = @rake
    # Rake.application.rake_require "tabletask"
    @instance = Rake::TableTask.define_task(:environment)
  end
  def test_use_copy_is_default
    assert_equal(true,@instance.use_copy?)
    assert_equal(false,@instance.use_insert?)
  end
  def test_use_insert_bang_inverts_use_copy?
    @instance.use_insert = true
    assert_equal(false,@instance.use_copy?)
    assert_equal(true,@instance.use_insert?)
  end

  def test_column_default_names
    assert_equal(:the_geog, @instance.geography_column)
    assert_equal(:the_geom, @instance.geometry_column)
    assert_equal(:gid, @instance.id_column)
  end

  def test_as_geography_not_default
    assert_equal(false,@instance.as_geography?)
  end
  
end
