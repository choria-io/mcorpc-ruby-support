#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  module Data
    describe Result do
      before(:each) do
        @result = Result.new({})
      end

      describe "#initialize" do
        it "should initialize empty values for all output fields" do
          result = Result.new({:rspec1 => {}, :rspec2 => {}})
          expect(result[:rspec1]).to eq(nil)
          expect(result[:rspec2]).to eq(nil)
        end

        it "should set default values for all output fields" do
          result = Result.new({:rspec1 => {:default => 1}, :rspec2 => {}})
          expect(result[:rspec1]).to eq(1)
          expect(result[:rspec2]).to eq(nil)
        end
      end

      describe "#[]=" do
        it "should only allow trusted types of data to be saved" do
          expect { @result["rspec"] = Time.now }.to raise_error("Can only store String, Integer, Float or Boolean data but got Time for key rspec")
          @result["rspec"] = 1
          @result["rspec"] = 1.1
          @result["rspec"] = "rspec"
          @result["rspec"] = true
          @result["rspec"] = false
        end

        it "should set the correct value" do
          @result["rspec"] = "rspec value"
          expect(@result.instance_variable_get("@data")).to eq({:rspec => "rspec value"})
        end

        it "should only allow valid data types" do
          expect { @result["rspec"] = Time.now }.to raise_error(/Can only store .+ data but got Time for key rspec/)
        end
      end

      describe "#include" do
        it "should return the correct list of keys" do
          @result["x"] = "1"
          @result[:y] = "2"
          expect(@result.keys.sort).to eq([:x, :y])
        end
      end

      describe "#include?" do
        it "should correctly report that a key is present or absent" do
          expect(@result.include?("rspec")).to eq(false)
          expect(@result.include?(:rspec)).to eq(false)
          @result["rspec"] = "rspec"
          expect(@result.include?("rspec")).to eq(true)
          expect(@result.include?(:rspec)).to eq(true)
        end
      end

      describe "#[]" do
        it "should retrieve the correct information" do
          expect(@result["rspec"]).to eq(nil)
          expect(@result[:rspec]).to eq(nil)
          @result["rspec"] = "rspec value"
          expect(@result["rspec"]).to eq("rspec value")
          expect(@result[:rspec]).to eq("rspec value")
        end
      end

      describe "#method_missing" do
        it "should raise the correct exception for unknown keys" do
          expect { @result.nosuchdata }.to raise_error(NoMethodError)
        end

        it "should retrieve the correct data" do
          @result["rspec"] = "rspec value"
          expect(@result.rspec).to eq("rspec value")
        end
      end
    end
  end
end
