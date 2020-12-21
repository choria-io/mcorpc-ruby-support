#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  module RPC
    describe Reply do
      before(:each) do
        Cache.delete!(:ddl) rescue nil

        ddl = stub
        ddl.stubs(:action_interface).returns({:output => {}})
        ddl.stubs(:actions).returns(["rspec"])
        ddl.stubs(:pluginname).returns("rspec")

        @reply = Reply.new("rspec", ddl)
      end

      describe "#initialize" do
        it "should set an empty data hash" do
          expect(@reply.data).to eq({})
        end

        it "should set statuscode to zero" do
          expect(@reply.statuscode).to eq(0)
        end

        it "should set statusmsg to OK" do
          expect(@reply.statusmsg).to eq("OK")
        end
      end

      describe "#initialize_data" do
        before do
          Log.stubs(:warn)
          @ddl = DDL.new("rspec", :agent, false)
        end

        it "should set defaults correctly" do
          @ddl.action :rspec, :description => "testing rspec" do
            @ddl.output :one, :description => "rspec test", :display_as => "rspec", :default => "default"
            @ddl.output :three, :description => "rspec test", :display_as => "rspec", :default => []
            @ddl.output :two, :description => "rspec test", :display_as => "rspec"
          end

          reply = Reply.new(:rspec, @ddl)
          expect(reply.data).to eq({:one => "default", :two => nil, :three => []})
        end

        it "should detect missing actions" do
          reply = Reply.new(:rspec, @ddl)
          expect { reply.initialize_data }.to raise_error(/No action 'rspec' defined/)
        end
      end

      describe "#fail" do
        it "should set statusmsg" do
          @reply.fail "foo"
          expect(@reply.statusmsg).to eq("foo")
        end

        it "should set statuscode to 1 by default" do
          @reply.fail("foo")
          expect(@reply.statuscode).to eq(1)
        end

        it "should set statuscode" do
          @reply.fail("foo", 2)
          expect(@reply.statuscode).to eq(2)
        end
      end

      describe "#fail!" do
        it "should set statusmsg" do
          expect {
            @reply.fail! "foo"
          }.to raise_error(RPCAborted, "foo")

          expect(@reply.statusmsg).to eq("foo")
        end

        it "should set statuscode to 1 by default" do
          expect {
            @reply.fail! "foo"
          }.to raise_error(RPCAborted)
        end

        it "should set statuscode" do
          expect {
            @reply.fail! "foo", 2
          }.to raise_error(UnknownRPCAction)

          expect(@reply.statuscode).to eq(2)
        end

        it "should raise RPCAborted for code 1" do
          expect {
            @reply.fail! "foo", 1
          }.to raise_error(RPCAborted)
        end

        it "should raise UnknownRPCAction for code 2" do
          expect {
            @reply.fail! "foo", 2
          }.to raise_error(UnknownRPCAction)
        end

        it "should raise MissingRPCData for code 3" do
          expect {
            @reply.fail! "foo", 3
          }.to raise_error(MissingRPCData)
        end

        it "should raise InvalidRPCData for code 4" do
          expect {
            @reply.fail! "foo", 4
          }.to raise_error(InvalidRPCData)
        end

        it "should raise UnknownRPCError for all other codes" do
          expect {
            @reply.fail! "foo", 5
          }.to raise_error(UnknownRPCError)

          expect {
            @reply.fail! "foo", "x"
          }.to raise_error(UnknownRPCError)
        end
      end

      describe "#[]=" do
        it "should save the correct data to the data hash" do
          @reply[:foo] = "foo1"
          @reply["foo"] = "foo2"

          expect(@reply.data[:foo]).to eq("foo1")
          expect(@reply.data["foo"]).to eq("foo2")
        end
      end

      describe "#[]" do
        it "should return the correct saved data" do
          @reply[:foo] = "foo1"
          @reply["foo"] = "foo2"

          expect(@reply[:foo]).to eq("foo1")
          expect(@reply["foo"]).to eq("foo2")
        end
      end

      describe "#to_hash" do
        it "should have the correct keys" do
          expect(@reply.to_hash.keys.sort).to eq([:data, :statuscode, :statusmsg])
        end

        it "should have the correct statuscode" do
          @reply.fail "meh", 2
          expect(@reply.to_hash[:statuscode]).to eq(2)
        end

        it "should have the correct statusmsg" do
          @reply.fail "meh", 2
          expect(@reply.to_hash[:statusmsg]).to eq("meh")
        end

        it "should have the correct data" do
          @reply[:foo] = :bar
          expect(@reply.to_hash[:data][:foo]).to eq(:bar)
        end
      end
    end
  end
end
