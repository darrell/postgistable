$: << File.expand_path(File.dirname(__FILE__) + "/../lib/")

require 'boolean_attributable'
require 'test/unit'


class TestBooleanAttributable < Test::Unit::TestCase
  def setup
    @instance = Class.new{ extend BooleanAttributable;boolean_attr :a_boolean }.new
  end

  def test_default_is_false
    assert_equal(false,@instance.a_boolean?)
  end

  def test_setting_boolean_attr_to_anything_returns_true
    @instance.a_boolean='a string'
    assert_equal(true,@instance.a_boolean?)
    assert_not_equal('a string',@instance.a_boolean? )
  end

  def test_setting_boolean_attr_bang_sets_to_true
    @instance.a_boolean!
    assert_equal(true,@instance.a_boolean?)
  end
    
end