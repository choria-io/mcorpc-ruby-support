#!/usr/bin/env rspec

require 'spec_helper'

class Array
  describe "#in_groups_of" do
    it "should correctly group array members" do
      expect([1,2,3,4,5,6,7,8,9,10].in_groups_of(5)).to eq([[1,2,3,4,5], [6,7,8,9,10]])
    end

    it "should padd missing data with correctly" do
      arr = [1,2,3,4,5,6,7,8,9,10]

      expect(arr.in_groups_of(3)).to eq([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, nil, nil]])
      expect(arr.in_groups_of(3, 0)).to eq([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 0, 0]])
      expect(arr.in_groups_of(11)).to eq([[1,2,3,4,5, 6,7,8,9,10, nil]])
      expect(arr.in_groups_of(11, 0)).to eq([[1,2,3,4,5, 6,7,8,9,10, 0]])
    end

    it "should indicate when the last abtched was reached" do
      arr = [1,2,3,4,5,6,7,8,9,10]

      ctr = 0

      [1,2,3,4,5,6,7,8,9,10].in_groups_of(3) {|a, last_batch| ctr += 1 unless last_batch}

      expect(ctr).to eq(3)
    end
  end
end
