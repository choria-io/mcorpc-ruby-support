#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe Message do
    before do
      Config.instance.set_config_defaults("")
    end

    describe "#initialize" do
      it "should set defaults" do
        m = Message.new("payload", "message")
        expect(m.payload).to eq("payload")
        expect(m.message).to eq("message")
        expect(m.request).to eq(nil)
        expect(m.headers).to eq({})
        expect(m.agent).to eq(nil)
        expect(m.collective).to eq(nil)
        expect(m.type).to eq(:message)
        expect(m.filter).to eq(Util.empty_filter)
        expect(m.requestid).to eq(nil)
        expect(m.base64?).to eq(false)
        expect(m.options).to eq({})
        expect(m.discovered_hosts).to eq(nil)
        expect(m.ttl).to eq(60)
        expect(m.validated).to eq(false)
        expect(m.msgtime).to eq(0)
        m.expected_msgid == nil
      end

      it "should set all supplied options" do
        Message.any_instance.expects(:base64_decode!)

        m = Message.new("payload", "message", :base64 => true,
                        :agent => "rspecagent",
                        :headers => {:rspec => "test"},
                        :type => :rspec,
                        :filter => "filter",
                        :options => {:ttl => 30},
                        :collective => "collective")
        expect(m.payload).to eq("payload")
        expect(m.message).to eq("message")
        expect(m.request).to eq(nil)
        expect(m.headers).to eq({:rspec => "test"})
        expect(m.agent).to eq("rspecagent")
        expect(m.collective).to eq("collective")
        expect(m.type).to eq(:rspec)
        expect(m.filter).to eq("filter")
        expect(m.base64?).to eq(true)
        expect(m.options).to eq({:ttl => 30})
        expect(m.ttl).to eq(30)
      end

      it "if given a request it should set options based on the request" do
        request = mock
        request.expects(:agent).returns("request")
        request.expects(:collective).returns("collective")

        m = Message.new("payload", "message", :request => request)
        expect(m.agent).to eq("request")
        expect(m.collective).to eq("collective")
        expect(m.type).to eq(:reply)
        expect(m.request).to eq(request)
      end
    end

    describe "#reply_to=" do
      it "should only set the reply-to header for requests" do
        Config.instance.expects(:direct_addressing).returns(true)
        m = Message.new("payload", "message", :type => :reply)
        m.discovered_hosts = ["foo"]
        expect { m.reply_to = "foo" }.to raise_error(/reply targets/)

        [:request, :direct_request].each do |t|
          m.type = t
          m.reply_to = "foo"
          expect(m.reply_to).to eq("foo")
        end
      end
    end

    describe "#expected_msgid=" do
      it "should correctly set the property" do
        m = Message.new("payload", "message", :type => :reply)
        m.expected_msgid = "rspec test"
        expect(m.expected_msgid).to eq("rspec test")
      end

      it "should only be set for reply messages" do
        m = Message.new("payload", "message", :type => :request)

        expect {
          m.expected_msgid = "rspec test"
        }.to raise_error("Can only store the expected msgid for reply messages")
      end
    end

    describe "#base64_decode!" do
      it "should not decode if not encoded" do
        SSL.expects(:base64_decode).never
        m = Message.new("payload", "message")
      end

      it "should decode encoded messages" do
        SSL.expects(:base64_decode)
        m = Message.new("payload", "message", :base64 => true)
      end

      it "should set base64 to false after decoding" do
        SSL.expects(:base64_decode).with("payload")
        m = Message.new("payload", "message", :base64 => true)
        expect(m.base64?).to eq(false)
      end
    end

    describe "#base64_encode" do
      it "should not encode already encoded messages" do
        SSL.expects(:base64_encode).never
        Message.any_instance.stubs(:base64_decode!)
        m = Message.new("payload", "message", :base64 => true)
        m.base64_encode!
      end

      it "should encode plain messages" do
        SSL.expects(:base64_encode).with("payload")
        m = Message.new("payload", "message")
        m.base64_encode!
      end

      it "should set base64 to false after encoding" do
        SSL.expects(:base64_encode)
        m = Message.new("payload", "message")
        m.base64_encode!
        expect(m.base64?).to eq(true)
      end
    end

    describe "#base64?" do
      it "should correctly report base64 state" do
        m = Message.new("payload", "message")
        expect(m.base64?).to eq(m.instance_variable_get("@base64"))
      end
    end

    describe "#type=" do
      it "should only allow types to be set when discovered hosts were given" do
        m = Message.new("payload", "message")
        Config.instance.stubs(:direct_addressing).returns(true)

        expect {
          m.type = :direct_request
        }.to raise_error("Can only set type to :direct_request if discovered_hosts have been set")
      end

      it "should not allow direct_request to be set if direct addressing isnt enabled" do
        m = Message.new("payload", "message")
        Config.instance.stubs(:direct_addressing).returns(false)

        expect {
          m.type = :direct_request
        }.to raise_error("Direct requests is not enabled using the direct_addressing config option")
      end

      it "should only accept valid types" do
        m = Message.new("payload", "message")
        Config.instance.stubs(:direct_addressing).returns(true)

        expect {
          m.type = :foo
        }.to raise_error("Unknown message type foo")
      end

      it "should clear the filter in direct_request mode and add just an agent filter" do
        m = Message.new("payload", "message")
        m.discovered_hosts = ["rspec"]
        Config.instance.stubs(:direct_addressing).returns(true)

        m.filter = Util.empty_filter.merge({"cf_class" => ["test"]})
        m.agent = "rspec"
        m.type = :direct_request
        expect(m.filter).to eq(Util.empty_filter.merge({"agent" => ["rspec"]}))
      end

      it "should set the type" do
        m = Message.new("payload", "message")
        m.type = :request
        expect(m.type).to eq(:request)
      end
    end

    describe "#encode!" do
      it "should encode replies using the security plugin #encodereply" do
        request = mock
        request.stubs(:agent).returns("rspec_agent")
        request.stubs(:collective).returns("collective")
        request.stubs(:payload).returns({:requestid => "123", :callerid => "id=callerid"})

        security = mock
        security.expects(:encodereply).with('rspec_agent', 'payload', '123', 'id=callerid')
        security.expects(:valid_callerid?).with("id=callerid").returns(true)

        PluginManager.expects("[]").with("security_plugin").returns(security).twice

        m = Message.new("payload", "message", :request => request, :type => :reply)

        m.encode!
      end

      it "should encode requests using the security plugin #encoderequest" do
        security = mock
        security.expects(:encoderequest).with("identity", 'payload', '123', Util.empty_filter, 'rspec_agent', 'mcollective', 60).twice
        PluginManager.expects("[]").with("security_plugin").returns(security).twice

        Config.instance.expects(:identity).returns("identity").twice

        Message.any_instance.expects(:requestid).returns("123").twice

        m = Message.new("payload", "message", :type => :request, :agent => "rspec_agent", :collective => "mcollective")
        m.encode!

        m = Message.new("payload", "message", :type => :direct_request, :agent => "rspec_agent", :collective => "mcollective")
        m.encode!
      end

      it "should retain the requestid if it was specifically set" do
        security = mock
        security.expects(:encoderequest).with("identity", 'payload', '123', Util.empty_filter, 'rspec_agent', 'mcollective', 60)
        PluginManager.expects("[]").with("security_plugin").returns(security)

        Config.instance.expects(:identity).returns("identity")

        m = Message.new("payload", "message", :type => :request, :agent => "rspec_agent", :collective => "mcollective")
        m.expects(:create_reqid).never
        m.requestid = "123"
        m.encode!
        expect(m.requestid).to eq("123")
      end

      it "should not allow bad callerids when replying" do
        request = mock
        request.stubs(:agent).returns("rspec_agent")
        request.stubs(:collective).returns("collective")
        request.stubs(:payload).returns({:requestid => "123", :callerid => "caller/id"})

        security = mock
        security.expects(:valid_callerid?).with("caller/id").returns(false)
        PluginManager.expects("[]").with("security_plugin").returns(security)

        m = Message.new("payload", "message", :request => request, :type => :reply)

        expect {
          m.encode!
        }.to raise_error('callerid in original request is not valid, surpressing reply to potentially forged request')
      end
    end

    describe "#decode!" do
      it "should check for valid types" do
        expect {
          m = Message.new("payload", "message", :type => :foo)
          m.decode!
        }.to raise_error("Cannot decode message type foo")
      end

      it "should set state based on decoded message" do
        msg = mock
        msg.stubs(:include?).returns(true)
        msg.stubs("[]").with(:collective).returns("collective")
        msg.stubs("[]").with(:agent).returns("rspecagent")
        msg.stubs("[]").with(:filter).returns("filter")
        msg.stubs("[]").with(:requestid).returns("1234")
        msg.stubs("[]").with(:ttl).returns(30)
        msg.stubs("[]").with(:msgtime).returns(1314628987)

        security = mock
        security.expects(:decodemsg).returns(msg)
        PluginManager.expects("[]").with("security_plugin").returns(security)

        m = Message.new(msg, "message", :type => :reply)
        m.decode!

        expect(m.collective).to eq("collective")
        expect(m.agent).to eq("rspecagent")
        expect(m.filter).to eq("filter")
        expect(m.requestid).to eq("1234")
        expect(m.ttl).to eq(30)
      end

      it "should not allow bad callerids from the security plugin on requests" do
        security = mock
        security.expects(:decodemsg).returns({:callerid => "foo/bar"})
        security.expects(:valid_callerid?).with("foo/bar").returns(false)

        PluginManager.expects("[]").with("security_plugin").returns(security).twice

        m = Message.new("payload", "message", :type => :request)

        expect {
          m.decode!
        }.to raise_error('callerid in request is not valid, surpressing reply to potentially forged request')
      end

      it 'should handle the securityprovider failing to decodemsg - log for reply' do
        security = mock('securityprovider')
        security.expects(:decodemsg).raises('squirrel attack')

        PluginManager.expects("[]").with("security_plugin").returns(security).once

        m = Message.new("payload", "message", :type => :reply)
        m.stubs(:headers).returns({'mc_sender' => 'trees'})
        Log.expects(:warn).with("Failed to decode a message from 'trees': squirrel attack")

        expect {
          m.decode!
        }.to_not raise_error
      end

      it 'should handle the securityprovider failing to decodemsg' do
        security = mock('securityprovider')
        security.expects(:decodemsg).raises('squirrel attack')

        PluginManager.expects("[]").with("security_plugin").returns(security).once

        m = Message.new("payload", "message", :type => :request)
        Log.expects(:warn).never

        expect {
          m.decode!
        }.to raise_error(/squirrel attack/)
      end

    end

    describe "#validate" do
      it "should only validate requests" do
        m = Message.new("msg", "message", :type => :reply)
        expect {
          m.validate
        }.to raise_error("Can only validate request messages")
      end

      it "should raise an exception for incorrect messages" do
        sec = mock
        sec.expects("validate_filter?").returns(false)
        PluginManager.expects("[]").with("security_plugin").returns(sec)

        payload = mock
        payload.expects("[]").with(:filter).returns({})
        payload.expects(:include?).with(:callerid).returns(false)
        payload.expects("[]").with(:senderid).returns('sender')

        m = Message.new(payload, "message", {:type => :request, :collective => 'collective',
                                             :agent => 'rspecagent', :requestid => '1234'})
        m.instance_variable_set("@msgtime", Time.now.to_i)

        expect {
          m.validate
        }.to raise_error(NotTargettedAtUs,
                         "Message 1234 for agent 'rspecagent' in collective 'collective' from sender does not pass filters. Ignoring message.")
      end

      it "should pass for good messages" do
        sec = mock
        sec.expects(:validate_filter?).returns(true)
        PluginManager.expects("[]").returns(sec)

        payload = mock
        payload.expects("[]").with(:filter).returns({})
        m = Message.new(payload, "message", :type => :request)
        m.instance_variable_set("@msgtime", Time.now.to_i)
        m.validate
      end

      it "should set the @validated property" do
        sec = mock
        sec.expects(:validate_filter?).returns(true)
        PluginManager.expects("[]").returns(sec)

        payload = mock
        payload.expects("[]").with(:filter).returns({})
        m = Message.new(payload, "message", :type => :request)
        m.instance_variable_set("@msgtime", Time.now.to_i)

        expect(m.validated).to eq(false)
        m.validate
        expect(m.validated).to eq(true)
      end

      it "should not validate for messages older than TTL" do
        m = Message.new({:callerid => "caller", :senderid => "sender"}, "message",
                        {:type => :request, :collective => 'collective',
                         :agent => 'rspecagent', :requestid => '1234'})
        mtime = Time.now.to_i - 120
        m.instance_variable_set("@msgtime", mtime)

        expect {
          m.validate
        }.to raise_error(MsgTTLExpired,
                         /Message 1234 for agent 'rspecagent' in collective 'collective' from caller@sender created at #{mtime} is 1[12][019] seconds old, TTL is 60. Rejecting message./)
      end
    end

    describe "#publish" do
      it "should publish itself to the connector" do
        m = Message.new("msg", "message", :type => :request)

        connector = mock
        connector.expects(:publish).with(m)
        PluginManager.expects("[]").returns(connector)

        m.publish
      end

      it "should support direct addressing" do
        m = Message.new("msg", "message", :type => :request)
        m.discovered_hosts = ["one", "two", "three"]

        Config.instance.stubs(:direct_addressing).returns(true)
        Config.instance.stubs(:direct_addressing_threshold).returns(10)

        connector = mock
        connector.expects(:publish).with(m)
        PluginManager.expects("[]").returns(connector)

        m.publish
        expect(m.type).to eq(:direct_request)
      end

      it "should only direct publish below the configured threshold" do
        m = Message.new("msg", "message", :type => :request)
        m.discovered_hosts = ["one", "two", "three"]

        Config.instance.expects(:direct_addressing).returns(true)
        Config.instance.expects(:direct_addressing_threshold).returns(1)

        connector = mock
        connector.expects(:publish).with(m)
        PluginManager.expects("[]").returns(connector)

        m.publish
        expect(m.type).to eq(:request)
      end
    end

    describe "#create_reqid" do
      it "should create a valid request id" do
        m = Message.new("msg", "message", :agent => "rspec", :collective => "mc")

        SSL.expects(:uuid).returns("reqid")

        expect(m.create_reqid).to eq("reqid")
      end
    end
  end
end
