#!/usr/bin/env rspec

require 'spec_helper'

require 'mcollective/data/collective_data'

module MCollective
  module Data
    describe Collective_data do
      describe "#query_data" do
        before :each do
          @ddl = mock('DDL')
          @ddl.stubs(:dataquery_interface).returns({:output => {}})
          @ddl.stubs(:meta).returns({:timeout => 1})
          DDL.stubs(:new).returns(@ddl)
          @plugin = Collective_data.new

          Config.instance.stubs(:collectives).returns([ "collective_a", "collective_b" ])
        end

        it 'should return true if you are a member of the named collective' do
          @plugin.query_data("collective_a")
          expect(@plugin.result[:member]).to eq(true)
        end

        it 'should return false if you are a member of the named collective' do
          @plugin.query_data("no_such_collective")
          expect(@plugin.result[:member]).to eq(false)
        end
      end
    end
  end
end
