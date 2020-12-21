#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  module Security
    describe Base do
      before do
        @config = mock("config")
        @config.stubs(:identity).returns("test")
        @config.stubs(:configured).returns(true)
        @config.stubs(:topicsep).returns(".")

        @stats = mock("stats")

        @time = Time.now
        ::Time.stubs(:now).returns(@time)

        MCollective::Log.stubs(:debug).returns(true)

        MCollective::PluginManager << {:type => "global_stats", :class => @stats}
        MCollective::Config.stubs("instance").returns(@config)
        MCollective::Util.stubs("empty_filter?").returns(false)

        @plugin = Base.new
      end

      describe "#should_process_msg?" do
        it "should correctly validate messages" do
          m = mock
          m.stubs(:expected_msgid).returns("rspec")

          expect(@plugin.should_process_msg?(m, "rspec")).to eq(true)

          expect {
            expect(@plugin.should_process_msg?(m, "fail")).to eq(true)
          }.to raise_error(MsgDoesNotMatchRequestID)
        end

        it "should not test messages without expected_msgid" do
          m = mock
          m.stubs(:expected_msgid).returns(nil)

          expect(@plugin.should_process_msg?(m, "rspec")).to eq(true)
        end
      end

      describe "#validate_filter?" do
        it "should pass on empty filter" do
          MCollective::Util.stubs("empty_filter?").returns(true)

          @stats.stubs(:passed).once
          @stats.stubs(:filtered).never
          @stats.stubs(:passed).never

          MCollective::Log.expects(:debug).with("Message passed the filter checks").once

          expect(@plugin.validate_filter?({})).to eq(true)
        end

        it "should pass for known classes" do
          MCollective::Util.stubs("has_cf_class?").with("foo").returns(true)

          @stats.stubs(:passed).once
          @stats.stubs(:filtered).never

          MCollective::Log.expects(:debug).with("Message passed the filter checks").once
          MCollective::Log.expects(:debug).with("Passing based on configuration management class foo").once

          expect(@plugin.validate_filter?({"cf_class" => ["foo"]})).to eq(true)
        end

        it "should fail for unknown classes" do
          MCollective::Util.stubs("has_cf_class?").with("foo").returns(false)

          @stats.stubs(:filtered).once
          @stats.stubs(:passed).never

          MCollective::Log.expects(:debug).with("Message failed the filter checks").once
          MCollective::Log.expects(:debug).with("Failing based on configuration management class foo").once

          expect(@plugin.validate_filter?({"cf_class" => ["foo"]})).to eq(false)
        end

        it "should pass for known agents" do
          MCollective::Util.stubs("has_agent?").with("foo").returns(true)

          @stats.stubs(:passed).once
          @stats.stubs(:filtered).never

          MCollective::Log.expects(:debug).with("Message passed the filter checks").once
          MCollective::Log.expects(:debug).with("Passing based on agent foo").once

          expect(@plugin.validate_filter?({"agent" => ["foo"]})).to eq(true)
        end

        it "should fail for unknown agents" do
          MCollective::Util.stubs("has_agent?").with("foo").returns(false)

          @stats.stubs(:filtered).once
          @stats.stubs(:passed).never

          MCollective::Log.expects(:debug).with("Message failed the filter checks").once
          MCollective::Log.expects(:debug).with("Failing based on agent foo").once

          expect(@plugin.validate_filter?({"agent" => ["foo"]})).to eq(false)
        end

        it "should pass for known facts" do
          MCollective::Util.stubs("has_fact?").with("fact", "value", "operator").returns(true)

          @stats.stubs(:passed).once
          @stats.stubs(:filtered).never

          MCollective::Log.expects(:debug).with("Message passed the filter checks").once
          MCollective::Log.expects(:debug).with("Passing based on fact fact operator value").once

          expect(@plugin.validate_filter?({"fact" => [{:fact => "fact", :operator => "operator", :value => "value"}]})).to eq(true)
        end

        it "should fail for unknown facts" do
          MCollective::Util.stubs("has_fact?").with("fact", "value", "operator").returns(false)

          @stats.stubs(:filtered).once
          @stats.stubs(:passed).never

          MCollective::Log.expects(:debug).with("Message failed the filter checks").once
          MCollective::Log.expects(:debug).with("Failing based on fact fact operator value").once

          expect(@plugin.validate_filter?({"fact" => [{:fact => "fact", :operator => "operator", :value => "value"}]})).to eq(false)
        end

        it "should pass for known identity" do
          MCollective::Util.stubs("has_identity?").with("test").returns(true)

          @stats.stubs(:passed).once
          @stats.stubs(:filtered).never

          MCollective::Log.expects(:debug).with("Message passed the filter checks").once
          MCollective::Log.expects(:debug).with("Passing based on identity").once

          expect(@plugin.validate_filter?({"identity" => ["test"]})).to eq(true)
        end

        it "should fail for known identity" do
          MCollective::Util.stubs("has_identity?").with("test").returns(false)

          @stats.stubs(:passed).never
          @stats.stubs(:filtered).once

          MCollective::Log.expects(:debug).with("Message failed the filter checks").once
          MCollective::Log.expects(:debug).with("Failed based on identity").once

          expect(@plugin.validate_filter?({"identity" => ["test"]})).to eq(false)
        end

        it "should treat multiple identity filters correctly" do
          MCollective::Util.stubs("has_identity?").with("foo").returns(false)
          MCollective::Util.stubs("has_identity?").with("bar").returns(true)

          @stats.stubs(:passed).once
          @stats.stubs(:filtered).never

          MCollective::Log.expects(:debug).with("Message passed the filter checks").once
          MCollective::Log.expects(:debug).with("Passing based on identity").once

          expect(@plugin.validate_filter?({"identity" => ["foo", "bar"]})).to eq(true)
        end

        it "should fail if no identity matches are found" do
          MCollective::Util.stubs("has_identity?").with("foo").returns(false)
          MCollective::Util.stubs("has_identity?").with("bar").returns(false)

          @stats.stubs(:passed).never
          @stats.stubs(:filtered).once

          MCollective::Log.expects(:debug).with("Message failed the filter checks").once
          MCollective::Log.expects(:debug).with("Failed based on identity").once

          expect(@plugin.validate_filter?({"identity" => ["foo", "bar"]})).to eq(false)
        end
      end

      describe "#create_reply" do
        it "should return correct data" do
          expected = {:senderid => "test",
            :requestid => "reqid",
            :senderagent => "agent",
            :msgtime => @time.to_i,
            :body => "body"}

          expect(@plugin.create_reply("reqid", "agent", "body")).to eq(expected)
        end
      end

      describe "#create_request" do
        it "should return correct data" do
          expected = {:body => "body",
            :senderid => "test",
            :requestid => "reqid",
            :callerid => "uid=#{Process.uid}",
            :agent => "discovery",
            :collective => "mcollective",
            :filter => "filter",
            :ttl => 20,
            :msgtime => @time.to_i}

          expect(@plugin.create_request("reqid", "filter", "body", :server, "discovery", "mcollective", 20)).to eq(expected)
        end

        it "should set the callerid when appropriate" do
          expected = {:body => "body",
            :senderid => "test",
            :requestid => "reqid",
            :agent => "discovery",
            :collective => "mcollective",
            :filter => "filter",
            :callerid => "callerid",
            :ttl => 60,
            :msgtime => @time.to_i}

          @plugin.stubs(:callerid).returns("callerid")
          expect(@plugin.create_request("reqid", "filter", "body", :client, "discovery", "mcollective")).to eq(expected)
        end
      end

      describe "#valid_callerid?" do
        it "should not pass invalid callerids" do
          expect(@plugin.valid_callerid?("foo-bar")).to eq(false)
          expect(@plugin.valid_callerid?("foo=bar=baz")).to eq(false)
          expect(@plugin.valid_callerid?('foo=bar\baz')).to eq(false)
          expect(@plugin.valid_callerid?("foo=bar/baz")).to eq(false)
          expect(@plugin.valid_callerid?("foo=bar|baz")).to eq(false)
        end

        it "should pass valid callerids" do
          expect(@plugin.valid_callerid?("cert=foo-bar")).to eq(true)
          expect(@plugin.valid_callerid?("uid=foo.bar")).to eq(true)
          expect(@plugin.valid_callerid?("uid=foo.bar.123")).to eq(true)
        end
      end

      describe "#callerid" do
        it "should return a unix UID based callerid" do
          expect(@plugin.callerid).to eq("uid=#{Process.uid}")
        end
      end

      describe "#validrequest?" do
        it "should log an error when not implemented" do
          MCollective::Log.expects(:error).with("validrequest? is not implemented in MCollective::Security::Base")
          @plugin.validrequest?(nil)
        end
      end

      describe "#encoderequest" do
        it "should log an error when not implemented" do
          MCollective::Log.expects(:error).with("encoderequest is not implemented in MCollective::Security::Base")
          @plugin.encoderequest(nil, nil, nil)
        end
      end

      describe "#encodereply" do
        it "should log an error when not implemented" do
          MCollective::Log.expects(:error).with("encodereply is not implemented in MCollective::Security::Base")
          @plugin.encodereply(nil, nil, nil)
        end
      end

      describe "#decodemsg" do
        it "should log an error when not implemented" do
          MCollective::Log.expects(:error).with("decodemsg is not implemented in MCollective::Security::Base")
          @plugin.decodemsg(nil)
        end
      end
    end
  end
end
