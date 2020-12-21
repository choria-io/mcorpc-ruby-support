#!/usr/bin/env rspec

require 'spec_helper'

class String
  describe "#start_with?" do
    it "should return true for matches" do
      expect("hello world".start_with?("hello")).to eq(true)
    end

    it "should return false for non matches" do
      expect("hello world".start_with?("world")).to eq(false)
    end
  end
end
