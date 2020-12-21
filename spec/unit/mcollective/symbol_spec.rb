#!/usr/bin/env rspec

require 'spec_helper'

class Symbol
  describe "#<=>" do
    it "should be sortable" do
      expect([:foo, :bar].sort).to eq([:bar, :foo])
    end
  end
end
