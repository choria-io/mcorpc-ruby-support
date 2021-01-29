#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe Client do
    let(:client) do
      c = Client.new("/nonexisting")
      c.options = Util.default_options
      c
    end

    before :each do
      @security = mock
      @security.stubs(:initiated_by=)
      @connector = mock
      @connector.stubs(:connect)
      @connector.stubs(:subscribe)
      @connector.stubs(:unsubscribe)
      @ddl = mock
      @ddl.stubs(:meta).returns({:timeout => 1})
      @discoverer = mock

      Discovery.expects(:new).returns(@discoverer)

      Config.instance.instance_variable_set("@configured", true)
      PluginManager.expects("[]").with("connector_plugin").returns(@connector)
      PluginManager.expects("[]").with("security_plugin").returns(@security)
      Timeout.stubs(:timeout).with(nil, MCollective::ClientTimeoutError)
    end

    describe "#initialize" do
      it "should set a timeout if a timeout has been specified" do
        Timeout.expects(:timeout).with(1, MCollective::ClientTimeoutError)
        Client.new({:config => "/nonexisting", :connection_timeout => 1})
      end

      it "should try forever if no timeout has been set" do
        Timeout.expects(:timeout).with(nil, MCollective::ClientTimeoutError)
        Client.new({:config => "/nonexisting"})
      end
    end

    describe "#sendreq" do
      it "should send the supplied message" do
        request = mock
        request.stubs(:agent)
        request.stubs(:ttl)
        request.stubs(:collective)
        client.expects(:createreq).with(request, "rspec", {}).returns(request)
        request.expects(:publish)
        request.expects(:requestid).returns("13fegbcw").twice
        result = client.sendreq(request, "rspec")
        expect(result).to eq("13fegbcw")
      end
    end

    describe "#createreq" do
      it "should create a request" do
        message = Message.new("rspec", nil, {:agent => "rspec", :type => :request, :collective => "mcollective", :filter => Util.empty_filter, :options => Util.default_options})
        message.stubs(:encode!)
        client.stubs(:subscribe)
        message.stubs(:reply_to)
        result = client.createreq(message, "rspec")
        expect(result).to eq(message)
      end

      it "should create a new request if the message if not of type Message" do
        message = mock
        message.stubs(:encode!)
        client.stubs(:subscribe)
        message.stubs(:reply_to)
        Message.expects(:new).returns(message)
        result = client.createreq("message", "rspec")
        expect(result).to eq(message)
      end

      it "should subscripe to the reply queue unless has been specified" do
        message = Message.new("rspec", nil, {:agent => "rspec", :type => :request, :collective => "mcollective", :filter => Util.empty_filter, :options => Util.default_options})
        message.stubs(:encode!)
        client.expects(:subscribe).with("rspec", :reply)
        message.stubs(:reply_to).returns(nil)
        client.createreq(message, "rspec")
      end

      it "should not subscribe to the reply queue if one has been specified" do
        message = Message.new("rspec", nil, {:agent => "rspec", :type => :request, :collective => "mcollective", :filter => Util.empty_filter, :options => Util.default_options})
        message.stubs(:encode!)
        client.expects(:subscribe).never
        message.stubs(:reply_to).returns(:reply)
        client.createreq(message, "rspec")
      end
    end

    describe "#subscribe" do
      it "should subscribe to a destination if it hasn't already" do
        subscription = mock
        Util.stubs(:make_subscriptions).returns(subscription)
        Util.expects(:subscribe).with(subscription)
        client.subscribe("rspec", :queue)
        expect(client.instance_variable_get(:@subscriptions)).to eq({"rspec" => 1})
      end

      it "should not subscribe to a destination if it already has" do
        client.instance_variable_get(:@subscriptions)["rspec"] = 1
        Util.expects(:make_subscription).never
        client.subscribe("rspec", :queue)
      end
    end

    describe "#unsubscribe" do
      it "should unsubscribe if a subscription has been made" do
        subscription = mock
        client.instance_variable_get(:@subscriptions)["rspec"] = 1
        Util.expects(:make_subscriptions).returns(subscription)
        Util.expects(:unsubscribe).with(subscription)
        client.unsubscribe("rspec", :queue)
      end

      it "should no unsubscribe if a subscription hasn't been made" do
        Util.expects(:make_subscription).never
        client.unsubscribe("rspec", :queue)
      end
    end

    describe "receive" do
      let(:message) do
        m = mock('message')
        m.stubs(:type=)
        m.stubs(:expected_msgid=)
        m.stubs(:decode!)
        m.stubs(:requestid).returns("erfs123")
        m.stubs(:payload).returns({:senderid => 'test-sender'})
        m
      end

      let(:badmessage) do
        m = mock('badmessage')
        m.stubs(:type=)
        m.stubs(:expected_msgid=)
        m.stubs(:decode!)
        m.stubs(:requestid).returns("badmessage")
        m.stubs(:payload).returns({})
        m
      end

      it "should receive a message" do
        @connector.stubs(:receive).returns(message)
        result = client.receive("erfs123")
        expect(result).to eq(message)
      end

      it 'should log who the message was from' do
        @connector.stubs(:receive).returns(message)
        Log.expects(:debug).with("Received reply to erfs123 from test-sender")

        client.receive("erfs123")
      end

      it "should log and retry if the message reqid does not match the expected msgid" do
        Log.stubs(:debug)
        Log.expects(:debug).with("Ignoring a message for some other client : Message reqid badmessage does not match our reqid erfs123")
        @connector.stubs(:receive).returns(badmessage, message)
        client.receive("erfs123")
      end

      it "should log and retry if a SecurityValidationFailed expection is raised" do
        Log.expects(:warn).with("Ignoring a message that did not pass security validations")
        badmessage.stubs(:decode!).raises(SecurityValidationFailed)
        @connector.stubs(:receive).returns(badmessage, message)
        client.receive("erfs123")
      end
    end

    describe "#discover" do
      it "should delegate to the discovery plugins" do
        @discoverer.expects(:discover).with({'collective' => 'mcollective'}, 1, 0, client).returns([])
        expect(client.discover({}, 1)).to eq([])
      end
    end

    describe "#req" do
      let(:message) do
        m = Message.new("rspec", nil, {:agent => "rspec",
                                       :type => :request,
                                       :collective => "mcollective",
                                       :filter => Util.empty_filter,
                                       :options => Util.default_options})
        m.discovered_hosts = ["rspec"]
        m
      end

      let(:request) do
        r = mock
        r.stubs(:requestid).returns("erfs123")
        r
      end

      before :each do
        client.expects(:unsubscribe)
        @discoverer.expects(:discovery_timeout).with(message.options[:timeout], message.options[:filter]).returns(0)
        client.stubs(:createreq).returns(request)
        client.expects(:update_stat)
      end

      it "should thread the publisher and receiver if configured" do
        client.instance_variable_get(:@options)[:threaded] = true
        client.expects(:threaded_req).with(request, 2, 0, ['rspec'])
        message.options[:threaded] = true
        client.req(message)
      end

      it "should not thread the publisher and receiver if configured" do
        client.instance_variable_set(:@threaded, false)
        client.expects(:unthreaded_req).with(request, 2, 0, ['rspec'])
        client.req(message)
      end

      it "uses the publish_timeout from options when passed as an option" do
        client.expects(:unthreaded_req).with(request, 5, 0, ['rspec'])
        client.req(message, nil, message.options.merge(:publish_timeout => 5))
      end

      it "uses the publish_timeout from config when passed as a config value" do
        client.expects(:unthreaded_req).with(request, 10, 0, ['rspec'])
        client.instance_variable_get(:@config).expects(:publish_timeout).returns(10)
        client.req(message)
      end
    end

    describe "#unthreaded_req" do
      it "should start a publisher and then start a receiver" do
        request = mock
        request.stubs(:requestid).returns("erfs123")
        client.expects(:start_publisher).with(request, 5)
        client.expects(:start_receiver).with("erfs123", 2, 10)
        client.unthreaded_req(request, 5, 10, 2)
      end
    end

    describe "#threaded_req" do
      it "should start a publisher thread and a receiver thread" do
        request = mock
        request.stubs(:requestid).returns("erfs123")
        p_thread = mock
        r_thread = mock
        Thread.expects(:new).yields.returns(p_thread)
        Thread.expects(:new).yields.returns(r_thread)
        client.expects(:start_publisher).with(request, 5)
        client.expects(:start_receiver).with("erfs123", 2, 15).returns(2)
        p_thread.expects(:join)
        result = client.threaded_req(request, 5, 10, 2)
        expect(result).to eq(2)
      end
    end

    describe "#start_publisher" do
      let(:message) do
        m = mock
        m.stubs(:requestid)
        m.stubs(:agent)
        m.stubs(:ttl)
        m.stubs(:collective)
        m
      end

      it "should publish the message" do
        Timeout.stubs(:timeout).with(2).yields
        message.expects(:publish)
        client.start_publisher(message, 2)
      end

      it "should log a warning on a timeout" do
        Timeout.stubs(:timeout).with(2).raises(Timeout::Error)
        Log.expects(:warn).with("Could not publish all messages. Publishing timed out.")
        client.start_publisher(message,2)
      end
    end

    describe "#start_receiver" do
      describe "waitfor is a number" do
        it "should go into a receive loop and receive until it reaches waitfor" do
          results = []
          Timeout.stubs(:timeout).yields
          message = mock
          client.stubs(:receive).with("erfs123").returns(message)
          message.stubs(:payload).returns("msg1", "msg2", "msg3")
          client.start_receiver("erfs123", 3, 5) do |msg|
            results << msg
          end
          expect(results).to eq(["msg1", "msg2", "msg3"])
        end

        it "should support responding with the payload and the Message" do
          results = []
          Timeout.stubs(:timeout).yields

          msg1 = mock(:payload => "msg1")
          msg2 = mock(:payload => "msg2")
          msg3 = mock(:payload => "msg3")

          client.stubs(:receive).with("erfs123").returns(msg1, msg2, msg3)
          client.start_receiver("erfs123", 3, 5) do |payload, message|
            results << [payload, message]
          end

          expect(results).to eq([["msg1", msg1], ["msg2", msg2], ["msg3", msg3]])
        end

        it "should log a warning if a timeout occurs" do
          results = []
          Timeout.stubs(:timeout).yields
          message = mock
          client.stubs(:receive).with("erfs123").returns(message)
          message.stubs(:payload).returns("msg1", "msg2", "timeout")
          Log.expects(:warn).with("Could not receive all responses. Expected : 3. Received : 2")
          responded = client.start_receiver("erfs123", 3, 5) do |msg|
            if msg == "timeout"
              raise Timeout::Error
            end
            results << msg
          end
          expect(results).to eq(["msg1", "msg2"])
          expect(responded).to eq(2)
        end

        it "should not log a warning if a the response count is larger or equal to the expected number of responses" do
          results = []
          Timeout.stubs(:timeout).yields
          message = mock
          client.stubs(:receive).with("erfs123").returns(message)
          message.stubs(:payload).returns("msg1", "msg2", "timeout")
          Log.expects(:warn).never
          responded = client.start_receiver("erfs123", 2, 5) do |msg|
            if msg == "timeout"
              raise Timeout::Error
            end
            results << msg
          end
          expect(results).to eq(["msg1", "msg2"])
          expect(responded).to eq(2)
        end
      end

      describe "waitfor is an array" do
        it "should go into a receive loop and receive until it matches waitfor" do
          senders = ["sender1", "sender2", "sender3", "sender4"]
          expected = senders.map {|s| Message.new({:callerid => "caller", :senderid => s}, nil, :type => :reply)}
          results = []
          Timeout.stubs(:timeout).yields
          client.stubs(:receive).with("erfs123").returns(*expected)
          client.start_receiver("erfs123", senders[0,3], 5) do |msg|
            results << msg
          end
          expect(results).to eq(expected[0,3].map {|m| m.payload})
        end

        it "receive until it gets all expected responses" do
          senders = ["sender1", "sender2", "sender3", "sender4"]
          expected = senders.map {|s| Message.new({:callerid => "caller", :senderid => s}, nil, :type => :reply)}
          results = []
          Timeout.stubs(:timeout).yields
          client.stubs(:receive).with("erfs123").returns(*expected)
          client.start_receiver("erfs123", senders[1,3], 5) do |msg|
            results << msg
          end
          expect(results).to eq(expected.map {|m| m.payload})
        end

        it "should log a warning if a timeout occurs" do
          senders = ["sender1", "sender2", "sender3"]
          messages = ["msg1", "msg2", "timeout"]
          expected = senders.zip(messages).map {|s, m| Message.new({:callerid => "caller", :senderid => s, :body => m}, nil, :type => :reply)}
          results = []
          Timeout.stubs(:timeout).yields
          client.stubs(:receive).with("erfs123").returns(*expected)
          Log.expects(:warn).with("Could not receive all responses. Did not receive responses from sender3")
          responded = client.start_receiver("erfs123", senders, 5) do |msg|
            if msg[:body] == "timeout"
              raise Timeout::Error
            end
            results << msg
          end
          expect(results).to eq(expected[0,2].map {|m| m.payload})
          expect(responded).to eq(2)
        end

        it "should not log a warning if accepting all responses" do
          senders = ["sender1", "sender2", "sender3"]
          messages = ["msg1", "msg2", "timeout"]
          expected = senders.zip(messages).map {|s, m| Message.new({:callerid => "caller", :senderid => s, :body => m}, nil, :type => :reply)}
          results = []
          Timeout.stubs(:timeout).yields
          client.stubs(:receive).with("erfs123").returns(*expected)
          Log.expects(:warn).never
          responded = client.start_receiver("erfs123", [], 1) do |msg|
            if msg[:body] == "timeout"
              raise Timeout::Error
            end
            results << msg
          end
          expect(results).to eq(expected[0,2].map {|m| m.payload})
          expect(responded).to eq(2)
        end

        it "should not log a warning if the response count is larger or equal to the expected number of responses" do
          senders = ["sender1", "sender2", "sender3"]
          messages = ["msg1", "msg2", "timeout"]
          expected = senders.zip(messages).map {|s, m| Message.new({:callerid => "caller", :senderid => s, :body => m}, nil, :type => :reply)}
          results = []
          Timeout.stubs(:timeout).yields
          client.stubs(:receive).with("erfs123").returns(*expected)
          Log.expects(:warn).never
          responded = client.start_receiver("erfs123", senders[0,2], 5) do |msg|
            if msg[:body] == "timeout"
              raise Timeout::Error
            end
            results << msg
          end
          expect(results).to eq(expected[0,2].map {|m| m.payload})
          expect(responded).to eq(2)
        end
      end
    end

    describe "#update_stat" do
      let(:before) do
        { :starttime     => Time.now.to_f,
          :discoverytime => 0,
          :blocktime     => 0,
          :totaltime     => 0 }
      end

      let(:after) do
        { :starttime     => 10.0,
          :discoverytime => 0,
          :blocktime     => 10.0,
          :totaltime     => 10.0,
          :responses     => 5,
          :requestid     => "erfs123",
          :noresponsefrom  => [],
          :unexpectedresponsefrom => [] }
      end

      it "should update stats and return the stats hash" do
        Time.stubs(:now).returns(10, 20)
        expect(client.update_stat(before, 5, "erfs123")).to eq(after)
      end
    end

    describe "#discovered_req" do
      it "should raise a deprecation exception" do
        expect{
          client.discovered_req(nil, nil)
          }.to raise_error("Client#discovered_req has been removed, please port your agent and client to the SimpleRPC framework")
      end
    end
  end
end
