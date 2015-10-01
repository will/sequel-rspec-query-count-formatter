# Counts how many sql queries each example uses
#
# Usage:
#
#     bundle exec rspec --format QueryCountFormatter -r ./spec/support/query_count_formatter.rb spec
#     bundle exec rspec --format QueryCountFormatter -r ./spec/support/query_count_formatter.rb spec/path/to/specific/spec
class QueryCountFormatter
  RSpec::Core::Formatters.register self, :dump_summary, :example_passed, :example_pending, :example_failed
  BARS = " ▁▂▃▅▇"

  def initialize(output)
    @output=output
    configure
  end

  def example_passed(notification)
    @output << bar(notification, 42)
  end

  def example_failed(notification)
    @output << bar(notification, 41)
  end

  def example_pending(notification)
    @output << bar(notification, 43)
  end

  def dump_summary(notification)
    @output << "\n"
    examples = notification.examples.select{|e| e.metadata[:query_count]}.sort_by {|e| -e.metadata[:query_count]}
    examples.first(100).each do |e|
      @output << "#{e.metadata[:query_count].to_s.rjust(5)} #{e.full_description}\n       #{e.metadata[:location]}\n"
    end
  end

  private

  def bar(notification, code)
    idx = case notification.example.metadata[:query_count]
          when (0..10)
            0
          when (10..50)
            1
          when (50..100)
            2
          when (100..250)
            3
          when (250..500)
            4
          else
            5
          end
    "\033[#{code}m#{BARS[idx]}\033[0m"
  end

  def configure
    RSpec.configure do |config|
      config.before(:each) do
        @query_counter_io = StringIO.new
        Sequel::Model.db.logger = Logger.new(@query_counter_io)
      end

      config.after(:each) do |example|
        begin
          @query_counter_io.rewind
          example.metadata[:query_count] = @query_counter_io
                                             .each_line
                                             .select { |line| line.starts_with?("I, ") }
                                             .count
        rescue => e
          p e
        end
      end
    end
  end
end
