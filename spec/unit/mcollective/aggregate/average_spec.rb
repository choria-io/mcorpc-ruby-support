#!/usr/bin/env rspec

require 'spec_helper'
require 'mcollective/aggregate/average'

module MCollective
  class Aggregate
    describe Average do
      describe "#startup_hook" do
        it "should set the correct result hash" do
          result = Average.new(:test, [], "%d", :test_action)
          expect(result.result).to eq({:value => 0, :type => :numeric, :output => :test})
          expect(result.aggregate_format).to eq("%d")
        end

        it "should set a defauly aggregate_format if one isn't defined" do
          result = Average.new(:test, [], nil, :test_action)
          expect(result.aggregate_format).to eq("Average of test: %f")
        end
      end

      describe "#process_result" do
        it "should add the reply value to the result hash" do
          average = Average.new([:test], [], "%d", :test_action)
          average.process_result(1, {:test => 1})
          expect(average.result[:value]).to eq(1)
        end
      end

      describe "#summarize" do
        it "should calculate the average and return a result class" do
          result_obj = mock
          result_obj.stubs(:new).returns(:success)

          average = Average.new([:test], [], "%d", :test_action)
          average.process_result(10, {:test => 10})
          average.process_result(20, {:test => 20})
          average.stubs(:result_class).returns(result_obj)
          expect(average.summarize).to eq(:success)
          expect(average.result[:value]).to eq(15)
        end
      end
    end
  end
end
