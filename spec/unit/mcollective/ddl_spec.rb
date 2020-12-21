#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe DDL do
    before do
      Cache.delete!(:ddl) rescue nil
    end

    describe "#new" do
      it "should default to agent ddls" do
        DDL::AgentDDL.expects(:new).once
        DDL.new("rspec")
      end

      it "should return the correct plugin ddl class" do
        expect(DDL.new("rspec", :agent, false).class).to eq(DDL::AgentDDL)
      end

      it "should default to base when no specific class exist" do
        expect(DDL.new("rspec", :rspec, false).class).to eq(DDL::Base)
      end
    end

    describe "#load_and_cache" do
      it "should setup the cache" do
        Cache.setup(:ddl)

        Cache.expects(:setup).once.returns(true)
        DDL.load_and_cache("rspec", :agent, false)
      end

      it "should attempt to read from the cache and return found ddl" do
        Cache.expects(:setup)
        Cache.expects(:read).with(:ddl, "agent/rspec").returns("rspec")
        expect(DDL.load_and_cache("rspec", :agent, false)).to eq("rspec")
      end

      it "should handle cache misses then create and save a new ddl object" do
        Cache.expects(:setup)
        Cache.expects(:read).with(:ddl, "agent/rspec").raises("failed")
        Cache.expects(:write).with(:ddl, "agent/rspec", kind_of(DDL::AgentDDL)).returns("rspec")

        expect(DDL.load_and_cache("rspec", :agent, false)).to eq("rspec")
      end
    end

    describe "#string_to_number" do
      it "should turn valid strings into numbers" do
        ["1", "0", "9999"].each do |i|
          expect(DDL.string_to_number(i)).to be_a(Integer)
        end

        ["1.1", "0.0", "9999.99"].each do |i|
          expect(DDL.string_to_number(i).class).to eq(Float)
        end
      end

      it "should raise errors for invalid values" do
        expect { DDL.string_to_number("rspec") }.to raise_error("rspec does not look like a number")
      end
    end

    describe "#string_to_boolean" do
      it "should turn valid strings into boolean" do
        ["true", "yes", "1"].each do |t|
          expect(DDL.string_to_boolean(t)).to eq(true)
          expect(DDL.string_to_boolean(t.upcase)).to eq(true)
        end

        ["false", "no", "0"].each do |f|
          expect(DDL.string_to_boolean(f)).to eq(false)
          expect(DDL.string_to_boolean(f.upcase)).to eq(false)
        end
      end

      it "should raise errors for invalid values" do
        expect { DDL.string_to_boolean("rspec") }.to raise_error("rspec does not look like a boolean argument")
      end
    end
  end
end
