#!/usr/bin/env rspec

require 'spec_helper'
require 'mcollective/aggregate/summary'

module MCollective
  class Aggregate
    describe Summary do
      describe "#startup_hook" do
        it "should set the correct result hash" do
          result = Summary.new(:test, [], "%d", :test_action)
          expect(result.result).to eq({:value => {}, :type => :collection, :output => :test})
          expect(result.aggregate_format).to eq("%d")
        end

        it "should set a defauly aggregate_format if one isn't defined" do
          result = Summary.new(:test, [], nil, :test_action)
          expect(result.aggregate_format).to eq(:calculate)
        end
      end

      describe "#process_result" do
        it "should add the value to the result hash" do
          sum = Summary.new(:test, [], "%d", :test_action)
          sum.process_result(:foo, {:test => :foo})
          expect(sum.result[:value]).to eq({:foo => 1})
        end

        it "should add the reply values to the result hash if value is an array" do
          sum = Summary.new(:test, [], "%d", :test_action)
          sum.process_result([:foo, :foo, :bar], {:test => [:foo, :foo, :bar]})
          expect(sum.result[:value]).to eq({:foo => 2, :bar => 1})
        end
      end

      describe "#summarize" do
        it "should calculate an attractive format" do
          sum = Summary.new(:test, [], nil, :test_action)
          sum.result[:value] = {"shrt" => 1, "long key" => 1}
          expect(sum.summarize.aggregate_format).to eq("%8s = %s")
        end

        it "should calculate an attractive format when result type is not a string" do
          sum1 = Summary.new(:test, [], nil, :test_action)
          sum1.result[:value] = {true => 4, false => 5}
          expect(sum1.summarize.aggregate_format).to eq("%5s = %s")

          sum2 = Summary.new(:test, [], nil, :test_action)
          sum2.result[:value] = {1 => 1, 10 => 2}
          expect(sum2.summarize.aggregate_format).to eq("%2s = %s")
        end
      end
    end
  end
end
