#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  class Aggregate
    module Result
      describe NumericResult do
        describe "#to_s" do
          it "should return empty string when no results were computed" do
            expect(NumericResult.new({}, "test %d", :action).to_s).to eq("")
          end

          it "should return the correctly formatted string" do
            num = NumericResult.new({:value => 1}, "test %d", :action).to_s
            expect(num).to eq("test 1")
          end
        end
      end
    end
  end
end
