require 'test_helper'

class MetriCollectTest < Minitest::Test
  User = OpenStruct.new(count: 0, active_count: 0)
  System = OpenStruct.new(load_average: 0, used_memory: 0, free_memory: 0)
  Application = OpenStruct.new(errors: 0)

  def setup
    @publisher = MetriCollect::Publisher[:test]
    @watcher   = MetriCollect::Watcher[:test]

    MetriCollect.configure do |config|
      config.application("CareerArc") do |application|
        application.publishers :test
        application.watchers :test

        application.metrics do
          namespace "Application" do
            namespace "Users" do
              metric "Total" do
                value User.count
              end

              metric "Active" do
                value User.active_count
              end
            end
          end

          namespace "Unicorn" do
            metric "WorkerCount" do
              value rand(1..10)
            end

            group "Requests" do
              sock_path = "/home/deploy/www/career_arc/shared/system/.sock"
              stats = { sock_path => OpenStruct.new(active: rand(1..10), queued: rand(1..10)) }

              metric do
                value stats[sock_path].active
                dimensions "Type" => "Active"
              end

              metric do
                value stats[sock_path].queued
                dimensions "Type" => "Queued"
              end
            end
          end
        end
      end

      config.application("CareerBeam") do |application|
        application.publishers :test

        application.metrics do
          namespace "System" do
            metric "LoadAverage" do
              value System.load_average
            end

            namespace "Memory" do
              metric "Used" do
                value System.used_memory, unit: :megabytes
              end

              metric "Free" do
                name "FreeMemory"
                namespace "CareerBeam/System/FreeMemory"
                value System.free_memory, unit: :megabytes
                dimensions "Type" => "Free", "SystemId" => "Workstation-1"
                timestamp Time.now
              end
            end
          end
        end
      end

      config.application("Namespace") do |application|
        application.publishers :test
        application.prefix_metrics_with "development"

        application.metrics do
          namespace "System" do
            metric "LoadAverage" do
              value System.load_average
            end
          end
        end
      end

      config.template :instance do |name, &block|
        dimensions "InstanceId" => "i-123456"
      end

      config.application("Template") do |application|
        application.publishers :test

        application.metrics do
          metric "Instance" do
            template :instance
            value 25
            dimensions "Type" => "Specific"
          end

          group "InstanceGroup" do
            metric do
              template :instance
              value 10
              dimensions "Type" => "Group"
            end
          end
        end
      end

      config.application("Watchers") do |application|
        application.watchers :test

        application.metrics do
          metric "Errors" do
            value Application.errors
            watch do
              name "Error Rate Too High"
              description "Triggered when the Application error rate is too high"
              condition { sum.over_period(3600) > 10 }
            end
          end
        end
      end

      config.application("Roles") do |application|
        application.metrics do
          namespace "System" do
            metric "LoadAverage" do
              value rand(1..5)
            end
          end

          namespace "Redis", roles: [:cron] do
            metric "CommandsPerSecond" do
              value rand(1..1000)
            end
          end

          namespace "Unicorn", roles: [:web] do
            metric "Requests" do
              value rand(1..256)
            end
          end
        end
      end
    end

    @careerarc   = MetriCollect["CareerArc"]
    @careerbeam  = MetriCollect["CareerBeam"]
    @namespace   = MetriCollect["Namespace"]
    @template    = MetriCollect["Template"]
    @watchers    = MetriCollect["Watchers"]
    @roles       = MetriCollect["Roles"]
  end

  def test_metrics
    User.count = 50
    User.active_count = 25

    total, active, workers, active_requests, queued_requests = @careerarc.metrics.to_a

    assert_metric_equal total, value: 50, name: "Total", namespace: "CareerArc/Application/Users", unit: :count
    assert_metric_equal active, value: 25, name: "Active", namespace: "CareerArc/Application/Users", unit: :count
    assert_metric_equal workers, name: "WorkerCount", namespace: "CareerArc/Unicorn", unit: :count
    assert_metric_equal active_requests, name: "Requests", namespace: "CareerArc/Unicorn", dimensions: { "Type" => "Active" }
    assert_metric_equal queued_requests, name: "Requests", namespace: "CareerArc/Unicorn", dimensions: { "Type" => "Queued" }

    refute_nil active_requests.timestamp
    refute_nil queued_requests.timestamp

    assert_equal active_requests.timestamp.to_i, queued_requests.timestamp.to_i

    System.load_average = 0.75
    System.used_memory = 3000
    System.free_memory = 2000

    Time.stub :now, Time.at(0) do
      load_average, used, free = @careerbeam.metrics.to_a

      assert_metric_equal load_average, value: 0.75, name: "LoadAverage", namespace: "CareerBeam/System", unit: :count
      assert_metric_equal used, value: 3000, name: "Used", namespace: "CareerBeam/System/Memory", unit: :megabytes
      assert_metric_equal free, value: 2000, name: "FreeMemory", namespace: "CareerBeam/System/FreeMemory", unit: :megabytes,
        timestamp: Time.at(0), dimensions: { "Type" => "Free", "SystemId" => "Workstation-1" }
    end

    System.load_average = 0.25

    load_average, _ = @namespace.metrics.to_a

    assert_metric_equal load_average, value: 0.25, name: "LoadAverage", namespace: "Namespace/development/System", unit: :count

    instance, instance_group, _ = @template.metrics.to_a

    assert_metric_equal instance, name: "Instance", namespace: "Template", value: 25, dimensions: { "Type" => "Specific", "InstanceId" => "i-123456" }
    assert_metric_equal instance_group, name: "InstanceGroup", namespace: "Template", value: 10, dimensions: { "Type" => "Group", "InstanceId" => "i-123456" }
  end

  def test_publish
    User.count = 10
    User.active_count = 5
    total, active = @careerarc.metrics.to_a

    @careerarc.publish(total)

    assert @publisher.published?(total)
    refute @publisher.published?(active)

    @publisher.clear

    @careerarc.publish_all

    assert @publisher.published?(total)
    assert @publisher.published?(active)
  end

  def test_direct_publish
    timestamp = Time.now
    options   = {
      namespace: "CareerArc/Counters",
      name: "aae:heartbeat",
      value: 1,
      timestamp: timestamp,
      unit: :count
    }

    MetriCollect["Namespace"].publish(options)

    metric = @publisher.published.last

    assert_metric_equal metric, namespace: "CareerArc/development/Counters", name: "aae:heartbeat", value: 1, timestamp: timestamp, unit: :count

    options.merge!(template: :instance)

    MetriCollect["CareerArc"].publish(options)

    metric = @publisher.published.last

    assert_metric_equal metric, namespace: "CareerArc/Counters", name: "aae:heartbeat", value: 1, timestamp: timestamp, unit: :count, dimensions: { "InstanceId" => "i-123456" }

    MetriCollect["CareerArc"].publish do
      name "Direct Block Count"
      namespace "CareerArc/Counters"
      value 10, unit: :count
      timestamp timestamp
    end

    metric = @publisher.published.last

    assert_metric_equal metric, namespace: "CareerArc/Counters", name: "Direct Block Count", value: 10, timestamp: timestamp, unit: :count
  end

  def test_watchers
    Application.errors = 1
    errors = @watchers.metrics.to_a[0]
    watch = errors.watches[0]
    now = Time.now.to_i

    if now % 3600 >= 3598
      puts "Sleeping 5 seconds to make sure we don't cross a time boundary..."
      sleep 5
    end

    results = 10.times.map do
      @watcher.watch(errors)
      @watcher.status(watch.name)
    end

    assert_equal 0, results.count {|r| r != :ok}

    @watcher.watch(errors)

    assert_equal :triggered, @watcher.status(watch.name)
  end

  def test_direct_watchers
    timestamp = Time.now
    watch_name = "Queued Distributions Alarm"
    options   = {
      namespace: "CareerArc/Counters",
      name: "ade:dispatcher:distribution:queued",
      value: 1,
      timestamp: timestamp,
      unit: :count,
      watches: [{
        name: watch_name,
        description: "Triggered when there are too many queued distributions",
        evaluations: 1,
        statistic: :sum,
        period: 3600,
        comparison: :>,
        threshold: 10
      }]
    }

    if timestamp.to_i % 3600 >= 3598
      puts "Sleeping 5 seconds to make sure we don't cross a time boundary..."
      sleep 5
    end

    results = 10.times.map do
      @watchers.publish(options)
      @watcher.status(watch_name)
    end

    assert_equal 0, results.count {|r| r != :ok}

    @watchers.publish(options)

    assert_equal :triggered, @watcher.status(watch_name)
  end

  def test_roles
    cron = @roles.metric_ids([:cron])
    web  = @roles.metric_ids([:web])
    all  = @roles.metric_ids

    assert_includes cron, "Roles/Redis/CommandsPerSecond"
    assert_includes cron, "Roles/System/LoadAverage"
    refute_includes cron, "Roles/Unicorn/Requests"

    assert_includes web, "Roles/Unicorn/Requests"
    assert_includes web, "Roles/System/LoadAverage"
    refute_includes web, "Roles/Redis/CommandsPerSecond"

    assert_includes all, "Roles/System/LoadAverage"
    refute_includes all, "Roles/Unicorn/Requests"
    refute_includes all, "Roles/Redis/CommandsPerSecond"
  end

  def test_cloud_watch_publisher_grouping
    metric    = { name: "Metric" }
    publisher = MetriCollect::Publisher::CloudWatchPublisher.new(region: "us-east")
    group     = publisher.send(:array_to_groups, [metric], 20)

    assert_equal group, [[metric]]
  end

  def test_runner
    runner = MetriCollect::Runner.new("CareerArc", frequency: 5, iterations: 3)
    runner.start
  end

  private

  def assert_metric_equal(metric, attributes = {}, &block)
    attributes.each do |attribute, value|
      if attribute == :dimensions
        value.each_with_index do |(dimension_name, dimension_value), index|
          assert_equal dimension_name, metric.dimensions[index][:name]
          assert_equal dimension_value, metric.dimensions[index][:value]
        end
      else
        assert_equal value, metric.send(attribute)
      end
    end
  end
end
