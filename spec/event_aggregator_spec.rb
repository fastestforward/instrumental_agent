require 'spec_helper'

describe Instrumental::EventAggregator, "time and frequency operations" do
  it "should massage time values to match the start of a window" do
    agg = Instrumental::EventAggregator.new(frequency: 10)
    Timecop.freeze do
      start_of_minute = Time.now.to_i - (Time.now.to_i % 60)
      times_to_report = [start_of_minute + 5, start_of_minute + 15]
      
      times_to_report.each do |at_time|
        agg.put(Instrumental::Command.new("gauge", "abc", 5, Time.at(at_time), 1))
      end

      expect(agg.size).to eq(2)

      expected_values = [Instrumental::Command.new("gauge", "abc", 5, Time.at(start_of_minute), 1),
                         Instrumental::Command.new("gauge", "abc", 5, Time.at(start_of_minute + 10), 1)]
      expect(agg.values.values).to eq(expected_values)
    end
  end
end

describe Instrumental::EventAggregator do
  it "should aggregate put operations to a given frequency" do
    start_of_minute = Time.now.to_i - (Time.now.to_i % 60)
    Timecop.freeze(Time.at(start_of_minute)) do
      agg = Instrumental::EventAggregator.new(frequency: 30)
      (Time.now.to_i..(Time.now.to_i + 119)).each do |time|
        agg.put(Instrumental::Command.new("increment", "abc", 1, time, 1))
      end
      expect(agg.size).to eq(4)
      (Time.now.to_i..(Time.now.to_i + 119)).step(30).map do |time|
        expect(agg.values["abc:#{time}"]).to eq(Instrumental::Command.new("increment", "abc", 30, time, 30))
      end
    end
  end

  it "should aggregate put operations to the same metric and last type wins" do
    Timecop.freeze do
      agg = Instrumental::EventAggregator.new(frequency: 6)

      agg.put(Instrumental::Command.new("gauge", "hello", 3.0, Time.now, 1))
      agg.put(Instrumental::Command.new("increment", "hello", 4.0, Time.now, 1))
      
      expect(agg.size).to eq(1)
      expect(agg.values.values.first).to eq(Instrumental::Command.new("increment",
                                                                     "hello",
                                                                     7.0,
                                                                     agg.coerce_time(Time.now),
                                                                     2))
    end
  end
end
