#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  module Data
    describe Base do
      before do
        @ddl = mock
        @ddl.stubs(:dataquery_interface).returns({:output => {'rspec' => {}}})
        @ddl.stubs(:meta).returns({:timeout => 1})
      end

      describe "#initialize" do
        it "should set the plugin name, ddl and timeout and call the startup hook" do
          DDL.stubs(:new).returns(@ddl)
          Base.any_instance.expects(:startup_hook).once
          plugin = Base.new
          expect(plugin.name).to eq("base")
          expect(plugin.timeout).to eq(1)
          expect(plugin.result.class).to eq(Result)
        end
      end

      describe "#lookup" do
        before do
          DDL.stubs(:new).returns(@ddl)
          @plugin = Base.new
        end

        it "should validate the request" do
          @plugin.expects(:ddl_validate).with("hello world").returns(true)
          @plugin.stubs(:query_data)
          @plugin.lookup("hello world")
        end

        it "should query the plugin" do
          @plugin.stubs(:ddl_validate)
          @plugin.expects(:query_data).with("hello world")
          expect(@plugin.lookup("hello world").class).to eq(Result)
        end

        it "should raise MsgTTLExpired errors for Timeout errors" do
          @plugin.stubs(:ddl_validate)
          @plugin.expects(:query_data).raises(Timeout::Error)

          msg = "Data plugin base timed out on query 'hello world'"
          Log.expects(:error).with(msg)
          expect { @plugin.lookup("hello world") }.to raise_error(msg)
        end
      end

      describe "#query" do
        it "should create a new method" do
          class Rspec_data<Base; end
          Rspec_data.query { "rspec test" }

          DDL.stubs(:new).returns(@ddl)

          data = Rspec_data.new
          expect(data.query_data).to eq("rspec test")
        end
      end

      describe "#ddl_validate" do
        it "should validate the request using the Data class" do
          DDL.stubs(:new).returns(@ddl)
          plugin = Base.new
          Data.expects(:ddl_validate).with(@ddl, "rspec")
          plugin.ddl_validate("rspec")
        end
      end

      describe "#activate_when" do
        it "should create a new activate? method" do
          class Rspec_data<Base;end

          Rspec_data.activate_when { raise "rspec" }
          DDL.stubs(:new).returns(@ddl)
          expect { Rspec_data.activate? }.to raise_error("rspec")
        end
      end

      describe "#activate?" do
        it "should default to true" do
          expect(Base.activate?).to eq(true)
        end
      end
    end
  end
end
