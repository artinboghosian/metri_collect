require "test_helper"

class MetricDefinitionTest < Minitest::Test
  def setup
    @name = "Test"
    @namespace = "Metric/Definition"
    @application = MetriCollect::Application.new("TestApp")
    @group = MetriCollect::MetricDefinitionGroup.new(@application, @namespace, @name) do
      metric do
        value "Hello"
      end

      metric do
        value "World"
        dimensions "To" => "You"
      end
    end
  end

  def test_group
    hello, world = @group.call

    assert_equal "Test", hello.name
    assert_equal "Metric/Definition", hello.namespace
    assert_equal "Hello", hello.value

    assert_equal "Test", world.name
    assert_equal "Metric/Definition", world.namespace
    assert_equal "World", world.value
    assert_equal "To", world.dimensions.first[:name]
    assert_equal "You", world.dimensions.first[:value]
  end
end