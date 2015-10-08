require 'metri_collect'

MetriCollect.configure do |config|
  config.application("CareerArc") do |application|
    application.publishers :test

    application.metrics do
      namespace "Test" do
        metric "TheAnswer" do
          value 42
        end
        metric "Random" do
          value rand
        end
      end
    end
  end
end

runner = MetriCollect::Runner.new("CareerArc", frequency: 5)
runner.start

