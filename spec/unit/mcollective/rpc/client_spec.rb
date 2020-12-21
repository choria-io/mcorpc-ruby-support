#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  module RPC
    describe Client do
      before do
        @coreclient = mock
        @discoverer = mock

        ddl = DDL.new("foo", "agent", false)
        ddl.action("rspec", :description => "mock agent")

        ddl.stubs(:meta).returns({:timeout => 2})
        DDL.stubs(:new).returns(ddl)

        @discoverer.stubs(:force_direct_mode?).returns(false)
        @discoverer.stubs(:discovery_method).returns("mc")
        @discoverer.stubs(:force_discovery_method_by_filter).returns(false)
        @discoverer.stubs(:discovery_timeout).returns(2)
        @discoverer.stubs(:ddl).returns(ddl)

        @coreclient.stubs("options=")
        @coreclient.stubs(:collective).returns("mcollective")
        @coreclient.stubs(:timeout_for_compound_filter).returns(0)
        @coreclient.stubs(:discoverer).returns(@discoverer)

        Config.instance.stubs(:loadconfig).with("/nonexisting").returns(true)
        Config.instance.stubs(:direct_addressing).returns(true)
        Config.instance.stubs(:collectives).returns(["mcollective", "rspec"])
        MCollective::Client.stubs(:new).returns(@coreclient)

        @stderr = StringIO.new
        @stdout = StringIO.new
        @stdin = StringIO.new

        @client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
        @client.stubs(:ddl).returns(ddl)
      end

      describe "#rpc_result_from_reply" do
        it "should support symbol style replies" do
          raw_result = {
            :senderid => "rspec.id",
            :body => {
              :statuscode => 1,
              :statusmsg => "rspec status",
              :data => {
                :one => 1
              }
            }
          }

          result = @client.rpc_result_from_reply("rspec", "test", raw_result)

          expect(result.agent).to eq("rspec")
          expect(result.action).to eq("test")
          expect(result[:sender]).to eq("rspec.id")
          expect(result[:statuscode]).to eq(1)
          expect(result[:statusmsg]).to eq("rspec status")
          expect(result[:data]).to eq(:one => 1)
          expect(result.results).to eq(
            :sender => "rspec.id",
            :statuscode => 1,
            :statusmsg => "rspec status",
            :data => {:one => 1}
          )
        end

        it "should support string style replies" do
          raw_result = {
            "senderid" => "rspec.id",
            "body" => {
              "statuscode" => 1,
              "statusmsg" => "rspec status",
              "data" => {
                "one" => 1,
                "two" => 2
              }
            }
          }

          result = @client.rpc_result_from_reply("rspec", "test", raw_result)

          expect(result.agent).to eq("rspec")
          expect(result.action).to eq("test")
          expect(result[:sender]).to eq("rspec.id")
          expect(result[:statuscode]).to eq(1)
          expect(result[:statusmsg]).to eq("rspec status")
          expect(result[:data]).to eq("one" => 1, "two" => 2)
          expect(result.results).to eq(
            :sender => "rspec.id",
            :statuscode => 1,
            :statusmsg => "rspec status",
            :data => {"one" => 1, "two" => 2}
          )
        end
      end

      describe "#detect_and_set_stdin_discovery" do
        before(:each) do
          @client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting", :stdin => @stdin}})
        end

        it "should do nothing when a specific discovery method is set" do
          @client.stubs(:default_discovery_method).returns(false)
          @client.expects(:discovery_method).never
          @client.detect_and_set_stdin_discovery
        end

        it "should set the stdin method when something is on STDIN" do
          @client.stubs(:default_discovery_method).returns(true)
          @stdin.expects(:tty?).returns(false)
          @stdin.expects(:eof?).returns(false)
          @client.detect_and_set_stdin_discovery
          expect(@client.discovery_method).to eq("stdin")
          expect(@client.discovery_options).to eq(["auto"])
        end

        it "should not set STDIN discovery when interactive" do
          @client.stubs(:default_discovery_method).returns(true)
          @stdin.expects(:tty?).returns(true)
          @client.detect_and_set_stdin_discovery
          expect(@client.discovery_method).to eq("mc")
        end

        it "should not set STDIN discovery when nothing on STDIN" do
          @client.stubs(:default_discovery_method).returns(true)
          @stdin.expects(:tty?).returns(false)
          @stdin.expects(:eof?).returns(true)
          @client.detect_and_set_stdin_discovery
          expect(@client.discovery_method).to eq("mc")
        end
      end

      describe "#initialize" do
        it "should fail for missing DDLs" do
          DDL.stubs(:new).raises("DDL failure")
          expect { Client.new("foo", {:options => {:config => "/nonexisting"}}) }.to raise_error("DDL failure")
        end

        it "should set a empty filter when none is supplied" do
          filter = Util.empty_filter
          Util.expects(:empty_filter).once.returns(filter)

          Client.new("foo", :options => {:config => "/nonexisting"})
        end

        it "should default the discovery_timeout to nil" do
          c = Client.new("rspec", :options => {:config => "/nonexisting"})
          expect(c.instance_variable_get("@discovery_timeout")).to eq(nil)
        end

        it "should accept a supplied discovery_timeout" do
          c = Client.new("rspec", :options => {:config => "/nonexisting", :disctimeout => 10})
          expect(c.instance_variable_get("@discovery_timeout")).to eq(10)
        end

        it "should default to configured batch options" do
          expect(@client.batch_size).to eq(0)
          expect(@client.batch_sleep_time).to eq(1)

          Config.instance.stubs(:default_batch_size).returns(1000)
          Config.instance.stubs(:default_batch_sleep_time).returns(30)
          c = Client.new("rspec", :options => {})

          expect(c.batch_size).to eq(1000)
          expect(c.batch_sleep_time).to eq(30)
        end
      end

      describe "#validate_request" do
        it "should fail when a DDL isn't present" do
          @client.instance_variable_set("@ddl", nil)
          expect { @client.validate_request("rspec", {}) }.to raise_error("No DDL found for agent foo cannot validate inputs")
        end

        it "should validate the input arguments" do
          @client.ddl.expects(:set_default_input_arguments).with("rspec", {})
          @client.ddl.expects(:validate_rpc_request).with("rspec", {})
          @client.validate_request("rspec", {})
        end
      end

      describe "#process_results_with_block" do
        it "should inform the stats object correctly for passed requests" do
          response = {:senderid => "rspec", :body => {:statuscode => 0}}

          @client.stats.expects(:ok)
          @client.stats.expects(:node_responded).with("rspec")
          @client.stats.expects(:time_block_execution).with(:start)
          @client.stats.expects(:time_block_execution).with(:end)
          @client.expects(:aggregate_reply).returns("aggregate stub")

          blk = Proc.new {}

          expect(@client.process_results_with_block("rspec", response, blk, "")).to eq("aggregate stub")
        end

        it "should inform the stats object correctly for failed requests" do
          @client.stats.expects(:fail)
          @client.stats.expects(:node_responded).with("rspec")

          response = {:senderid => "rspec", :body => {:statuscode => 1}}
          blk = Proc.new {}

          @client.process_results_with_block("rspec", response, blk, nil)
        end

        it "should pass raw results for single arity blocks" do
          response = {:senderid => "rspec", :body => {:statuscode => 1}}
          blk = Proc.new {|r| expect(r).to eq(response)}

          @client.process_results_with_block("rspec", response, blk, nil)
        end

        it "should pass raw and rpc style results for 2 arity blocks" do
          response = {:senderid => "rspec", :body => {:statuscode => 1}}
          blk = Proc.new do |r, s|
            expect(r).to eq(response)
            expect(s.class).to eq(RPC::Result)
          end

          @client.process_results_with_block("rspec", response, blk, nil)
        end
      end

      describe "#process_results_without_block" do
        it "should inform the stats object correctly for passed requests" do
          response = {:senderid => "rspec", :body => {:statuscode => 0}}
          @client.stats.expects(:ok)
          @client.stats.expects(:node_responded).with("rspec")
          @client.process_results_without_block(response, "rspec", nil)
        end

        it "should inform the stats object correctly for failed requests" do
          @client.stats.expects(:fail).twice
          @client.stats.expects(:node_responded).with("rspec").twice

          response = {:senderid => "rspec", :body => {:statuscode => 1}}
          @client.process_results_without_block(response, "rspec", nil)

          response = {:senderid => "rspec", :body => {:statuscode => 3}}
          @client.process_results_without_block(response, "rspec", nil)
        end

        it "should return the result and the aggregate" do
          @client.expects(:aggregate_reply).returns("aggregate stub")

          response = {:senderid => "rspec", :body => {:statuscode => 0}}
          result = @client.rpc_result_from_reply("foo", "rspec", response)

          @client.stubs(:rpc_result_from_reply).with("foo", "rspec", response).returns(result)
          expect(@client.process_results_without_block(response, "rspec", "")).to eq([result, "aggregate stub"])
        end
      end

      describe "#load_aggregate_functions" do
        it "should not load if the ddl is not set" do
          expect(@client.load_aggregate_functions("rspec", nil)).to eq(nil)
        end

        it "should create the aggregate for the right action" do
          @client.ddl.expects(:action_interface).with("rspec").returns({:aggregate => []}).twice
          Aggregate.expects(:new).with(:aggregate => []).returns("rspec aggregate")
          expect(@client.load_aggregate_functions("rspec", @client.ddl)).to eq("rspec aggregate")
        end

        it "should log and return nil on failure" do
          @client.ddl.expects(:action_interface).raises("rspec")
          Log.expects(:error).with(regexp_matches(/Failed to load aggregate/))
          @client.load_aggregate_functions("rspec", @client.ddl)
        end
      end

      describe "#aggregate_reply" do
        it "should not call anything if the aggregate isnt set" do
          expect(@client.aggregate_reply(nil, nil)).to eq(nil)
        end

        it "should call the aggregate functions with the right data" do
          result = @client.rpc_result_from_reply("rspec", "rspec", {:body => {:data => "rspec"}})

          aggregate = mock
          aggregate.expects(:call_functions).with(result).returns(aggregate)

          expect(@client.aggregate_reply(result, aggregate)).to eq(aggregate)
        end

        it "should log and return nil on failure" do
          aggregate = mock
          aggregate.expects(:call_functions).raises

          Log.expects(:error).with(regexp_matches(/Failed to calculate aggregate summaries/))

          expect(@client.aggregate_reply({}, aggregate)).to eq(nil)
        end
      end

      describe "#collective=" do
        it "should validate the collective" do
          expect { @client.collective = "fail" }.to raise_error("Unknown collective fail")
          @client.collective = "rspec"
        end

        it "should set the collective" do
          expect(@client.options[:collective]).to eq("mcollective")
          @client.collective = "rspec"
          expect(@client.options[:collective]).to eq("rspec")
        end

        it "should reset the client" do
          @client.expects(:reset)
          @client.collective = "rspec"
        end
      end

      describe "#discovery_method=" do
        it "should set the method" do
          expect(@client.default_discovery_method).to eq(true)
          @client.discovery_method = "rspec"
          expect(@client.default_discovery_method).to eq(false)
          expect(@client.discovery_method).to eq("rspec")
        end

        it "should set initial options if provided" do
          client = Client.new("rspec", {:options => {:discovery_options => ["rspec"], :filter => Util.empty_filter, :config => "/nonexisting"}})
          client.discovery_method = "rspec"
          expect(client.discovery_method).to eq("rspec")
          expect(client.discovery_options).to eq(["rspec"])
          expect(client.default_discovery_method).to eq(false)
        end

        it "should clear the options if none are given initially" do
          @client.discovery_options = ["rspec"]
          @client.discovery_method = "rspec"
          expect(@client.discovery_options).to eq([])
        end

        it "should set the client options" do
          @client.expects(:options).returns("rspec")
          @client.client.expects(:options=).with("rspec")
          @client.discovery_method = "rspec"
        end

        it "should adjust timeout for the new method" do
          @client.expects(:discovery_timeout).once.returns(1)
          @client.discovery_method = "rspec"
          expect(@client.instance_variable_get("@timeout")).to eq(4)
        end

        it "should preserve any user supplied discovery timeout" do
          @client.discovery_timeout = 10
          @client.discovery_method = "rspec"
          expect(@client.discovery_timeout).to eq(10)
        end

        it "should reset the rpc client" do
          @client.expects(:reset)
          @client.discovery_method = "rspec"
        end
      end

      describe "#discovery_options=" do
        it "should flatten the options array" do
          @client.discovery_options = "foo"
          expect(@client.discovery_options).to eq(["foo"])
        end
      end

      describe "#class_filter" do
        it "should add a class to the filter" do
          @client.class_filter("rspec")
          expect(@client.filter["cf_class"]).to eq(["rspec"])
        end

        it "should be idempotent" do
          @client.class_filter("rspec")
          @client.class_filter("rspec")
          expect(@client.filter["cf_class"]).to eq(["rspec"])
        end
      end

      describe "#fact_filter" do
        before do
          Util.stubs(:parse_fact_string).with("rspec=present").returns({:value => "present", :fact => "rspec", :operator => "=="})
        end

        it "should add a fact to the filter" do
          @client.fact_filter("rspec", "present", "=")
          expect(@client.filter["fact"]).to eq([{:value=>"present", :fact=>"rspec", :operator=>"=="}])
        end

        it "should be idempotent" do
          @client.fact_filter("rspec", "present", "=")
          @client.fact_filter("rspec", "present", "=")
          expect(@client.filter["fact"]).to eq([{:value=>"present", :fact=>"rspec", :operator=>"=="}])
        end
      end

      describe "#agent_filter" do
        it "should add an agent to the filter" do
          expect(@client.filter["agent"]).to eq(["foo"])
        end

        it "should be idempotent" do
          @client.agent_filter("foo")
          expect(@client.filter["agent"]).to eq(["foo"])
        end
      end

      describe "#identity_filter" do
        it "should add a node to the filter" do
          @client.identity_filter("rspec_node")
          expect(@client.filter["identity"]).to eq(["rspec_node"])
        end

        it "should be idempotent" do
          @client.identity_filter("rspec_node")
          @client.identity_filter("rspec_node")
          expect(@client.filter["identity"]).to eq(["rspec_node"])
        end
      end

      describe "#compound_filter" do
        before do
          Matcher.stubs(:create_compound_callstack).with("filter").returns("filter")
        end

        it "should add a compound filter" do
          @client.compound_filter("filter")
          expect(@client.filter["compound"]).to eq(["filter"])
        end

        it "should be idempotent" do
          @client.compound_filter("filter")
          @client.compound_filter("filter")
          expect(@client.filter["compound"]).to eq(["filter"])
        end
      end

      describe "#discovery_timeout" do
        it "should favour the initial options supplied timeout" do
          client = Client.new("rspec", {:options => {:disctimeout => 3, :filter => Util.empty_filter, :config => "/nonexisting"}})
          expect(client.discovery_timeout).to eq(3)
        end

        it "should return the DDL data if no specific options are supplied" do
          client = Client.new("rspec", {:options => {:disctimeout => nil, :filter => Util.empty_filter, :config => "/nonexisting"}})
          expect(client.discovery_timeout).to eq(2)
        end
      end

      describe "#discovery_timeout=" do
        it "should store the discovery timeout" do
          @client.discovery_timeout = 10
          expect(@client.discovery_timeout).to eq(10)
        end

        it "should update the overall timeout with the new discovery timeout" do
          expect(@client.instance_variable_get("@timeout")).to eq(4)

          @client.discovery_timeout = 10

          expect(@client.instance_variable_get("@timeout")).to eq(12)
        end
      end

      describe "#limit_method" do
        it "should force strings to symbols" do
          @client.limit_method = "first"
          expect(@client.limit_method).to eq(:first)
        end

        it "should only allow valid methods" do
          @client.limit_method = :first
          expect(@client.limit_method).to eq(:first)
          @client.limit_method = :random
          expect(@client.limit_method).to eq(:random)

          expect { @client.limit_method = :fail }.to raise_error(/Unknown/)
          expect { @client.limit_method = "fail" }.to raise_error(/Unknown/)
        end
      end

      describe "#method_missing" do
        it "should reset the stats" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.stubs(:call_agent)

          Stats.any_instance.expects(:reset).once
          client.rspec
        end

        it "should validate the request against the ddl" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          client.stubs(:call_agent)

          client.expects(:validate_request).with("rspec", {:arg => :val}).raises("validation failed")

          expect { client.rspec(:arg => :val) }.to raise_error("validation failed")
        end

        it "should support limited targets" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.limit_targets = 10

          client.expects(:pick_nodes_from_discovered).with(10).returns(["one", "two"])
          client.expects(:custom_request).with("rspec", {}, ["one", "two"], {"identity" => /^(one|two)$/}).once

          client.rspec
        end

        describe "batch mode" do
          before do
            Config.instance.stubs(:direct_addressing).returns(true)
            @client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          end

          it "should support global batch_size" do
            @client.batch_size = 10
            @client.expects(:call_agent_batched).with("rspec", {}, @client.options, 10, 1)
            @client.rspec
          end

          it "should support custom batch_size" do
            @client.expects(:call_agent_batched).with("rspec", {}, @client.options, 10, 1)
            @client.rspec :batch_size => 10
          end

          it "should allow supplied batch_size override global one" do
            @client.batch_size = 10
            @client.expects(:call_agent_batched).with("rspec", {}, @client.options, 20, 1)
            @client.rspec :batch_size => 20
          end

          it "should support global batch_sleep_time" do
            @client.batch_size = 10
            @client.batch_sleep_time = 20
            @client.expects(:call_agent_batched).with("rspec", {}, @client.options, 10, 20)
            @client.rspec
          end

          it "should support custom batch_sleep_time" do
            @client.batch_size = 10
            @client.expects(:call_agent_batched).with("rspec", {}, @client.options, 10, 20)
            @client.rspec :batch_sleep_time => 20
          end

          it "should allow supplied batch_sleep_time override global one" do
            @client.batch_size = 10
            @client.batch_sleep_time = 10
            @client.expects(:call_agent_batched).with("rspec", {}, @client.options, 10, 20)
            @client.rspec :batch_sleep_time => 20
          end
        end

        it "should support normal calls" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          client.expects(:call_agent).with("rspec", {}, client.options, :auto).once

          client.rspec
        end
      end

      describe "#pick_nodes_from_discovered" do
        before do
          client = stub
          discoverer = stub
          ddl = stub

          ddl.stubs(:meta).returns({:timeout => 2})

          discoverer.stubs(:ddl).returns(ddl)

          client.stubs("options=")
          client.stubs(:collective).returns("mcollective")
          client.stubs(:discoverer).returns(discoverer)

          Config.instance.stubs(:loadconfig).with("/nonexisting").returns(true)
          MCollective::Client.stubs(:new).returns(client)
          Config.instance.stubs(:direct_addressing).returns(true)
        end

        it "should return a percentage of discovered hosts" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.stubs(:discover).returns((1..10).map{|i| i.to_s})
          client.limit_method = :first
          expect(client.pick_nodes_from_discovered("20%")).to eq(["1", "2"])
        end

        it "should return the same list when a random seed is supplied" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting", :limit_seed => 5}})
          client.stubs(:discover).returns((1..10).map{|i| i.to_s})
          client.limit_method = :random
          expect(client.pick_nodes_from_discovered("30%")).to eq(["3", "7", "8"])
          expect(client.pick_nodes_from_discovered("30%")).to eq(["3", "7", "8"])
          expect(client.pick_nodes_from_discovered("3")).to eq(["3", "7", "8"])
          expect(client.pick_nodes_from_discovered("3")).to eq(["3", "7", "8"])
        end

        it "should correctly pick a numeric amount of discovered nodes" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting", :limit_seed => 5}})
          client.stubs(:discover).returns((1..10).map{|i| i.to_s})
          client.limit_method = :first
          expect(client.pick_nodes_from_discovered(5)).to eq((1..5).map{|i| i.to_s})
          expect(client.pick_nodes_from_discovered(5)).to eq((1..5).map{|i| i.to_s})
        end
      end

      describe "#limit_targets=" do
        before do
          client = stub
          discoverer = stub
          ddl = stub

          ddl.stubs(:meta).returns({:timeout => 2})

          discoverer.stubs(:force_direct_mode?).returns(false)
          discoverer.stubs(:ddl).returns(ddl)
          discoverer.stubs(:discovery_method).returns("mc")

          client.stubs("options=")
          client.stubs(:collective).returns("mcollective")
          client.stubs(:discoverer).returns(discoverer)

          Config.instance.stubs(:loadconfig).with("/nonexisting").returns(true)
          MCollective::Client.expects(:new).returns(client)
          Config.instance.stubs(:direct_addressing).returns(true)

          @client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
        end

        it "should support percentages" do
          @client.limit_targets = "10%"
          expect(@client.limit_targets).to eq("10%")
        end

        it "should support integers" do
          @client.limit_targets = 10
          expect(@client.limit_targets).to eq(10)
          @client.limit_targets = "20"
          expect(@client.limit_targets).to eq(20)
          @client.limit_targets = 1.1
          expect(@client.limit_targets).to eq(1)
          @client.limit_targets = 1.7
          expect(@client.limit_targets).to eq(1)
        end

        it "should not allow invalid limits to be set" do
          expect { @client.limit_targets = "a" }.to raise_error(/Invalid/)
          expect { @client.limit_targets = "%1" }.to raise_error(/Invalid/)
          expect { @client.limit_targets = "1.1" }.to raise_error(/Invalid/)
        end

        it "should reset @limit_targets" do
          @client.limit_targets = 10
          expect(@client.limit_targets).to eq(10)
          @client.limit_targets = nil
          expect(@client.limit_targets).to eq(nil)
          @client.limit_targets = 10
          @client.limit_targets = false
          expect(@client.limit_targets).to eq(nil)
        end
      end

      describe "#fire_and_forget_request" do
        before do
          @client = stub
          @discoverer = stub
          @ddl = stub

          @ddl.stubs(:meta).returns({:timeout => 2})

          @discoverer.stubs(:force_direct_mode?).returns(false)
          @discoverer.stubs(:ddl).returns(@ddl)
          @discoverer.stubs(:discovery_method).returns("mc")

          @client.stubs("options=")
          @client.stubs(:collective).returns("mcollective")
          @client.stubs(:discoverer).returns(@discoverer)
          @client.stubs(:sendreq)

          Config.instance.stubs(:loadconfig).with("/nonexisting").returns(true)
          MCollective::Client.expects(:new).returns(@client)
          Config.instance.stubs(:direct_addressing).returns(true)

          @rpcclient = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          @rpcclient.stubs(:validate_request)
          @request = stub
          @rpcclient.stubs(:new_request).returns(@request)
        end

        it "should validate the request" do
          @rpcclient.expects(:validate_request).with("rspec", {:rspec => "test"}).raises("rspec")

          expect {
            @rpcclient.fire_and_forget_request("rspec", {:rspec => "test"})
          }.to raise_error("rspec")
        end

        it "should set the filter if it was specifically supplied" do
          message = mock
          Message.expects(:new).with(@request, nil, {:agent => "foo", :type => :request, :collective => "mcollective", :filter => "filter", :options => @rpcclient.options}).returns(message)

          @rpcclient.expects(:identity_filter_discovery_optimization)
          @rpcclient.fire_and_forget_request("rspec", {:rspec => "test"}, "filter")
        end

        it "should set reply_to if set" do
          message = mock
          Message.expects(:new).with(@request, nil, {:agent => "foo", :type => :request, :collective => "mcollective", :filter => @rpcclient.filter, :options => @rpcclient.options}).returns(message)

          @rpcclient.reply_to = "/reply/to"
          message.expects(:reply_to=).with("/reply/to")

          @rpcclient.expects(:identity_filter_discovery_optimization)
          @rpcclient.fire_and_forget_request("rspec", {:rspec => "test"})
        end

        it "should support direct_requests with discovery data supplied" do
          message = mock
          Message.expects(:new).with(@request, nil, {:agent => "foo", :type => :request, :collective => "mcollective", :filter => @rpcclient.filter, :options => @rpcclient.options}).returns(message)

          @rpcclient.discover :nodes => "rspec"
          message.expects(:discovered_hosts=).with(["rspec"])
          message.expects(:type=).with(:direct_request)

          @rpcclient.expects(:identity_filter_discovery_optimization)
          @rpcclient.fire_and_forget_request("rspec", {:rspec => "test"})
        end

        it "should support direct_requests with discoverers that force direct mode" do
          message = mock
          Message.expects(:new).with(@request, nil, {:agent => "foo", :type => :request, :collective => "mcollective", :filter => @rpcclient.filter, :options => @rpcclient.options}).returns(message)

          @discoverer.stubs(:force_direct_mode?).returns(true)
          @rpcclient.stubs(:discover).returns(["rspec"])

          message.expects(:discovered_hosts=).with(["rspec"])
          message.expects(:type=).with(:direct_request)

          @rpcclient.expects(:identity_filter_discovery_optimization)
          @rpcclient.fire_and_forget_request("rspec", {:rspec => "test"})
        end
      end

      describe "#call_agent_batched" do
        before do
          @client = stub
          @discoverer = stub
          @ddl = stub

          @ddl.stubs(:meta).returns({:timeout => 2})

          @discoverer.stubs(:force_direct_mode?).returns(false)
          @discoverer.stubs(:ddl).returns(@ddl)
          @discoverer.stubs(:discovery_method).returns("mc")

          @client.stubs("options=")
          @client.stubs(:collective).returns("mcollective")
          @client.stubs(:discoverer).returns(@discoverer)

          Config.instance.stubs(:loadconfig).with("/nonexisting").returns(true)
          MCollective::Client.expects(:new).returns(@client)
          Config.instance.stubs(:direct_addressing).returns(true)
        end

        it "should require direct addressing" do
          Config.instance.stubs(:direct_addressing).returns(false)
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          expect {
            client.send(:call_agent_batched, "foo", {}, {}, 1, 1)
          }.to raise_error("Batched requests requires direct addressing")
        end

        it "should require that all results be processed" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          expect {
            client.send(:call_agent_batched, "foo", {:process_results => false}, {}, 1, 1)
          }.to raise_error("Cannot bypass result processing for batched requests")
        end

        it "should only accept valid batch sizes" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          expect {
            client.send(:call_agent_batched, "foo", {}, {}, "foo", 1)
          }.to raise_error("batch_size must be an integer or match a percentage string (e.g. '24%'")
        end

        it "should only accept float sleep times" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          expect {
            client.send(:call_agent_batched, "foo", {}, {}, 1, "foo")
          }.to raise_error(/invalid value for Float/)
        end

        it "should batch hosts in the correct size" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting", :stderr => StringIO.new}})

          client.expects(:new_request).returns("req")

          discovered = mock
          discovered.stubs(:size).returns(1)
          discovered.stubs(:empty?).returns(false)
          discovered.expects(:in_groups_of).with(10).raises("spec pass")

          client.instance_variable_set("@client", @coreclient)
          @coreclient.stubs(:discover).returns(discovered)
          @coreclient.stubs(:timeout_for_compound_filter).returns(0)

          expect { client.send(:call_agent_batched, "foo", {}, {}, 10, 1) }.to raise_error("spec pass")
        end

        it "should force direct requests" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting", :stderr => StringIO.new}})

          Message.expects(:new).with('req', nil, {:type => :direct_request, :agent => 'foo', :filter => nil, :options => {}, :collective => 'mcollective'}).raises("spec pass")
          client.expects(:new_request).returns("req")

          client.instance_variable_set("@client", @coreclient)
          @coreclient.stubs(:discover).returns(["test"])
          @coreclient.stubs(:timeout_for_compound_filter).returns(0)

          expect { client.send(:call_agent_batched, "foo", {}, {}, 1, 1) }.to raise_error("spec pass")
        end

        it "should process blocks correctly" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting", :stderr => StringIO.new}})

          msg = mock
          msg.expects(:discovered_hosts=).times(10)
          msg.expects(:create_reqid).returns("823a3419a0975c3facbde121f72ab61f")
          msg.expects(:requestid=).with("823a3419a0975c3facbde121f72ab61f").times(10)

          # These stat keys must match the values returned by a generic Client, or `--batch` will break.
          stats = {:noresponsefrom => [], :unexpectedresponsefrom => [], :responses => 0, :blocktime => 0, :totaltime => 0, :discoverytime => 0, :requestid => "823a3419a0975c3facbde121f72ab61f"}

          Message.expects(:new).with('req', nil, {:type => :direct_request, :agent => 'foo', :filter => nil, :options => {}, :collective => 'mcollective'}).returns(msg).times(10)
          client.expects(:new_request).returns("req")
          client.expects(:sleep).with(1.0).times(9)

          client.instance_variable_set("@client", @coreclient)
          @coreclient.stubs(:discover).returns([1,2,3,4,5,6,7,8,9,0])
          @coreclient.expects(:req).with(msg).yields("result").times(10)
          @coreclient.stubs(:stats).returns stats
          @coreclient.stubs(:timeout_for_compound_filter).returns(0)

          client.expects(:process_results_with_block).with("foo", "result", instance_of(Proc), nil).times(10)

          result = client.send(:call_agent_batched, "foo", {}, {}, 1, 1) { }
          expect(result[:requestid]).to eq("823a3419a0975c3facbde121f72ab61f")
          expect(result.class).to eq(Stats)
        end

        it "should return an array of results in array mode" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting", :stderr => StringIO.new}})
          client.instance_variable_set("@client", @coreclient)

          msg = mock
          msg.expects(:discovered_hosts=).times(10)
          msg.expects(:create_reqid).returns("823a3419a0975c3facbde121f72ab61f")
          msg.expects(:requestid=).with("823a3419a0975c3facbde121f72ab61f").times(10)

          # These stat keys must match the values returned by a generic Client, or `--batch` will break.
          stats = {:noresponsefrom => [], :unexpectedresponsefrom => [], :responses => 0, :blocktime => 0, :totaltime => 0, :discoverytime => 0, :requestid => "823a3419a0975c3facbde121f72ab61f"}

          Progress.expects(:new).never

          Message.expects(:new).with('req', nil, {:type => :direct_request, :agent => 'foo', :filter => nil, :options => {}, :collective => 'mcollective'}).returns(msg).times(10)
          client.expects(:new_request).returns("req")
          client.expects(:sleep).with(1.0).times(9)

          @coreclient.stubs(:discover).returns([1,2,3,4,5,6,7,8,9,0])
          @coreclient.expects(:req).with(msg).yields("result").times(10)
          @coreclient.stubs(:stats).returns stats
          @coreclient.stubs(:timeout_for_compound_filter).returns(0)

          client.expects(:process_results_without_block).with("result", "foo", nil).returns("rspec").times(10)

          expect(client.send(:call_agent_batched, "foo", {}, {}, 1, 1)).to eq(["rspec", "rspec", "rspec", "rspec", "rspec", "rspec", "rspec", "rspec", "rspec", "rspec"])

          expect(client.stats[:requestid]).to eq("823a3419a0975c3facbde121f72ab61f")
        end
      end

      describe "#batch_sleep_time=" do
        it "should correctly set the sleep" do
          Config.instance.stubs(:direct_addressing).returns(true)

          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.batch_sleep_time = 5
          expect(client.batch_sleep_time).to eq(5)
        end

        it "should only allow batch sleep to be set for direct addressing capable clients" do
          Config.instance.stubs(:direct_addressing).returns(false)
          Config.instance.stubs(:loadconfig).with("/nonexisting").returns(true)
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          expect { client.batch_sleep_time = 5 }.to raise_error("Can only set batch sleep time if direct addressing is supported")
        end
      end

      describe "#batch_size=" do
        it "should correctly set the size" do
          Config.instance.stubs(:direct_addressing).returns(true)

          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          expect(client.batch_mode).to eq(false)
          client.batch_size = 5
          expect(client.batch_size).to eq(5)
          expect(client.batch_mode).to eq(true)
        end

        it "should only allow batch size to be set for direct addressing capable clients" do
          Config.instance.stubs(:loadconfig).with("/nonexisting").returns(true)
          Config.instance.stubs(:direct_addressing).returns(false)
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          expect { client.batch_size = 5 }.to raise_error("Can only set batch size if direct addressing is supported")
        end

        it "should accept batch sizes as percentage strings" do
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.batch_size = "50%"
          expect(client.batch_size).to eq("50%")
        end

        it "should support disabling batch mode when supplied a batch size of 0" do
          Config.instance.stubs(:direct_addressing).returns(true)

          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.batch_size = 5
          expect(client.batch_mode).to eq(true)
          client.batch_size = 0
          expect(client.batch_mode).to eq(false)
        end
      end

      describe "#discover" do
        it "should not accept invalid flags" do
          Config.instance.stubs(:direct_addressing).returns(true)
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})

          expect { client.discover(:rspec => :rspec) }.to raise_error("Unknown option rspec passed to discover")
        end

        it "should reset when :json, :hosts or :nodes are provided" do
          Config.instance.stubs(:direct_addressing).returns(true)
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.expects(:reset).times(3)
          client.discover(:hosts => ["one"])
          client.discover(:nodes => ["one"])
          client.discover(:json => ["one"])
        end

        it "should only allow discovery data in direct addressing mode" do
          Config.instance.stubs(:direct_addressing).returns(false)
          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          client.expects(:reset).once

          expect {
            client.discover(:nodes => ["one"])
          }.to raise_error("Can only supply discovery data if direct_addressing is enabled")
        end

        it "should parse :nodes and :hosts and force direct requests" do
          Config.instance.stubs(:direct_addressing).returns(true)
          Helpers.expects(:extract_hosts_from_array).with(["one"]).returns(["one"]).twice

          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          expect(client.discover(:nodes => ["one"])).to eq(["one"])
          expect(client.discover(:hosts => ["one"])).to eq(["one"])
          expect(client.instance_variable_get("@force_direct_request")).to eq(true)
          expect(client.instance_variable_get("@discovered_agents")).to eq(["one"])
        end

        it "should parse :json and force direct requests" do
          Config.instance.stubs(:direct_addressing).returns(true)
          Helpers.expects(:extract_hosts_from_json).with('["one"]').returns(["one"]).once

          client = Client.new("foo", {:options => {:filter => Util.empty_filter, :config => "/nonexisting"}})
          expect(client.discover(:json => '["one"]')).to eq(["one"])
          expect(client.instance_variable_get("@force_direct_request")).to eq(true)
          expect(client.instance_variable_get("@discovered_agents")).to eq(["one"])
        end

        it "should not set direct mode for non 'mc' discovery methods" do
          Config.instance.stubs(:direct_addressing).returns(true)

          client = Client.new("foo", {:options => {:discovery_method => "rspec", :filter => {"identity" => ["foo"], "agent" => []}, :config => "/nonexisting"}})
          @coreclient.expects(:discover).returns(["foo"])

          client.discover
          expect(client.instance_variable_get("@discovered_agents")).to eq(["foo"])
          expect(client.instance_variable_get("@force_direct_request")).to eq(false)
        end

        it "should force direct mode for non regex identity filters" do
          Config.instance.stubs(:direct_addressing).returns(true)

          client = Client.new("foo", {:options => {:discovery_method => "mc", :filter => {"identity" => ["foo"], "agent" => []}, :config => "/nonexisting"}})
          client.discover
          expect(client.instance_variable_get("@discovered_agents")).to eq(["foo"])
          expect(client.instance_variable_get("@force_direct_request")).to eq(true)
        end

        it "should not set direct mode if its disabled" do
          Config.instance.stubs(:direct_addressing).returns(false)

          client = Client.new("foo", {:options => {:discovery_method => "mc", :filter => {"identity" => ["foo"], "agent" => []}, :config => "/nonexisting"}})

          client.discover
          expect(client.instance_variable_get("@force_direct_request")).to eq(false)
          expect(client.instance_variable_get("@discovered_agents")).to eq(["foo"])
        end

        it "should not set direct mode for regex identities" do
          Config.instance.stubs(:direct_addressing).returns(false)

          rpcclient = Client.new("foo", {:options => {:filter => {"identity" => ["/foo/"], "agent" => []}, :config => "/nonexisting"}})

          rpcclient.client.expects(:discover).with({
            'identity' => ['/foo/'],
            'agent' => ['foo'],
            'collective' => 'mcollective',
          }, 2).once.returns(["foo"])

          rpcclient.discover
          expect(rpcclient.instance_variable_get("@force_direct_request")).to eq(false)
          expect(rpcclient.instance_variable_get("@discovered_agents")).to eq(["foo"])
        end

        it "should print status to stderr if in verbose mode" do
          @stderr.expects(:print).with("Discovering hosts using the mc method for 2 second(s) .... ")
          @stderr.expects(:puts).with(1)

          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => true,
              :disctimeout => 2,
              :stderr => @stderr,
              :stdout => @stdout,
            },
          })

          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])

          rpcclient.discover
        end

        it "should not print status to stderr if in nonverbose mode" do
          @stderr.expects(:print).never
          @stderr.expects(:puts).never

          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
              :stderr => @stderr,
              :stdout => @stdout,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])

          rpcclient.discover
        end

        it "should record the start and end times" do
          Stats.any_instance.expects(:time_discovery).with(:start)
          Stats.any_instance.expects(:time_discovery).with(:end)

          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])

          rpcclient.discover
        end

        it "should discover using limits in :first rpclimit mode given a number" do
          Config.instance.stubs(:rpclimitmethod).returns(:first)
          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2, 1).returns(["foo"])

          rpcclient.limit_targets = 1

          rpcclient.discover
        end

        it "should not discover using limits in :first rpclimit mode given a string" do
          Config.instance.stubs(:rpclimitmethod).returns(:first)
          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])
          rpcclient.limit_targets = "10%"

          rpcclient.discover
        end

        it "should not discover using limits when not in :first mode" do
          Config.instance.stubs(:rpclimitmethod).returns(:random)

          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])

          rpcclient.limit_targets = 1
          rpcclient.discover
        end

        it "should ensure force_direct mode is false when doing traditional discovery" do
          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])

          rpcclient.instance_variable_set("@force_direct_request", true)
          rpcclient.discover
          expect(rpcclient.instance_variable_get("@force_direct_request")).to eq(false)
        end

        it "should store discovered nodes in stats" do
          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])

          rpcclient.discover
          expect(rpcclient.stats.discovered_nodes).to eq(["foo"])
        end

        it "should save discovered nodes in RPC" do
          rpcclient = Client.new("foo", {
            :options => {
              :filter => Util.empty_filter,
              :config => "/nonexisting",
              :verbose => false,
              :disctimeout => 2,
            },
          })
          rpcclient.client.expects(:discover).with({
            'identity' => [],
            'compound' => [],
            'fact' => [],
            'agent' => ['foo'],
            'cf_class' => [],
            'collective' => 'mcollective',
          }, 2).returns(["foo"])

          RPC.expects(:discovered).with(["foo"]).once
          rpcclient.discover
        end
      end

      describe "#determine_batch_mode" do
        let(:rpcclient) do
          rpcclient = Client.new("foo",
                                 {:options => {:filter => Util.empty_filter,
                                               :config => "/nonexisting",
                                               :verbose => false,
                                               :disctimeout => 2}})
        end

        it "should return true when batch_mode should be set" do
          expect(rpcclient.send(:determine_batch_mode, "1")).to eq(true)
          expect(rpcclient.send(:determine_batch_mode, 1)).to eq(true)
          expect(rpcclient.send(:determine_batch_mode, "1%")).to eq(true)
        end

        it "should return false when batch_mode shouldn't be set" do
          expect(rpcclient.send(:determine_batch_mode, "0")).to eq(false)
          expect(rpcclient.send(:determine_batch_mode, 0)).to eq(false)
        end
      end

      describe "#validate_batch_size" do
        let(:rpcclient) do
          rpcclient = Client.new("foo",
                                 {:options => {:filter => Util.empty_filter,
                                               :config => "/nonexisting",
                                               :verbose => false,
                                               :disctimeout => 2}})
        end

        it "should fail when batch size is an invalid string" do
          expect {
            rpcclient.send(:validate_batch_size, "foo")
          }.to raise_error("batch_size must be an integer or match a percentage string (e.g. '24%'")
        end

        it "should fail when batch size is 0%" do
          expect {
            rpcclient.send(:validate_batch_size, "0%")
          }.to raise_error("batch_size must be an integer or match a percentage string (e.g. '24%'")
        end

        it "should fail when batch size is not a valid string or integer" do
          expect {
            rpcclient.send(:validate_batch_size, true)
          }.to raise_error("batch_size must be an integer or match a percentage string (e.g. '24%'")
        end
      end
    end
  end
end
