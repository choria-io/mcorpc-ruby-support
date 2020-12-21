#!/usr/bin/env rspec

require 'spec_helper'

class MCollective::Connector::Stomp<MCollective::Connector::Base; end

module MCollective
  describe Util do
    before do

      PluginManager.clear
      PluginManager << {:type => "connector_plugin", :class => MCollective::Connector::Stomp.new}
    end

    describe "#windows?" do
      it "should correctly detect windows on unix platforms" do
        RbConfig::CONFIG.expects("[]").returns("linux")
        expect(Util.windows?).to eq(false)
      end

      it "should correctly detect windows on windows platforms" do
        RbConfig::CONFIG.expects("[]").returns("win32")
        expect(Util.windows?).to eq(true)
      end
    end

    describe "#setup_windows_sleeper" do
      it "should set up a thread on the windows platform" do
        Thread.expects(:new)
        Util.expects("windows?").returns(true).once
        Util.setup_windows_sleeper
      end

      it "should not set up a thread on other platforms" do
        Thread.expects(:new).never
        Util.expects("windows?").returns(false).once
        Util.setup_windows_sleeper
      end
    end

    describe "#has_cf_class?" do
      before do
        logger = mock
        logger.stubs(:log)
        logger.stubs(:start)
        Log.configure(logger)

        config = mock
        config.stubs(:classesfile).returns("/some/file")
        Config.expects(:instance).returns(config)
      end

      it "should read the classes lines from the correct file" do
        File.expects(:readlines).with("/some/file")

        Util.has_cf_class?("test")
      end

      it "should support regular expression searches" do
        tc = "test_class_test"
        File.stubs(:readlines).returns([tc])
        expect(Util.has_cf_class?("/class/")).to eq(true)
      end

      it "should support exact string matches" do
        File.stubs(:readlines).returns(["test_class_test"])
        expect(Util.has_cf_class?("test_class_test")).to eq(true)
      end

      it "should report a warning when the classes file cannot be parsed" do
        File.stubs(:readlines).returns(nil)
        Log.expects(:warn).with("Parsing classes file '/some/file' failed: NoMethodError: undefined method `each' for nil:NilClass")

        expect(Util.has_cf_class?("test_class_test")).to eq(false)
      end
    end

    describe "#shellescape" do
      it "should return '' for empty strings" do
        expect(Util.shellescape("")).to eq("''")
      end

      it "should quote newlines" do
        expect(Util.shellescape("\n")).to eq("'\n'")
      end

      it "should escape unwanted characters" do
        expect(Util.shellescape("foo;bar")).to eq('foo\;bar')
        expect(Util.shellescape('foo`bar')).to eq('foo\`bar')
        expect(Util.shellescape('foo$bar')).to eq('foo\$bar')
        expect(Util.shellescape('foo|bar')).to eq('foo\|bar')
        expect(Util.shellescape('foo&&bar')).to eq('foo\&\&bar')
        expect(Util.shellescape('foo||bar')).to eq('foo\|\|bar')
        expect(Util.shellescape('foo>bar')).to eq('foo\>bar')
        expect(Util.shellescape('foo<bar')).to eq('foo\<bar')
        expect(Util.shellescape('foobar')).to eq('foobar')
      end
    end

    describe "#make_subscription" do
      it "should validate target types" do
        expect {
          Util.make_subscriptions("test", "test", "test")
        }.to raise_error("Unknown target type test")

        Config.instance.stubs(:collectives).returns(["test"])
        Util.make_subscriptions("test", :broadcast, "test")
      end

      it "should return a subscription for each collective" do
        Config.instance.stubs(:collectives).returns(["collective1", "collective2"])
        expect(Util.make_subscriptions("test", :broadcast)).to eq([{:type=>:broadcast,
                                                                 :agent=>"test",
                                                                 :collective=>"collective1"},
                                                               {:type=>:broadcast,
                                                                 :agent=>"test",
                                                                 :collective=>"collective2"}])
      end

      it "should validate given collective" do
        Config.instance.stubs(:collectives).returns(["collective1", "collective2"])

        expect {
          Util.make_subscriptions("test", :broadcast, "test")
        }.to raise_error("Unknown collective 'test' known collectives are 'collective1, collective2'")
      end

      it "should return a single subscription array given a collective" do
        Config.instance.stubs(:collectives).returns(["collective1", "collective2"])
        expect(Util.make_subscriptions("test", :broadcast, "collective1")).to eq([{:type=>:broadcast, :agent=>"test", :collective=>"collective1"}])
      end
    end

    describe "#subscribe" do
      it "should subscribe to multiple topics given an Array" do
        subs1 = {:agent => "test_agent", :type => "test_type", :collective => "test_collective"}
        subs2 = {:agent => "test_agent2", :type => "test_type2", :collective => "test_collective2"}

        MCollective::PluginManager["connector_plugin"].expects(:subscribe).with("test_agent", "test_type", "test_collective").once
        MCollective::PluginManager["connector_plugin"].expects(:subscribe).with("test_agent2", "test_type2", "test_collective2").once

        Util.subscribe([subs1, subs2])
      end

      it "should subscribe to a single topic given a hash" do
        MCollective::PluginManager["connector_plugin"].expects(:subscribe).with("test_agent", "test_type", "test_collective").once
        Util.subscribe({:agent => "test_agent", :type => "test_type", :collective => "test_collective"})
      end
    end

    describe "#unsubscribe" do
      it "should unsubscribe to multiple topics given an Array" do
        subs1 = {:agent => "test_agent", :type => "test_type", :collective => "test_collective"}
        subs2 = {:agent => "test_agent2", :type => "test_type2", :collective => "test_collective2"}
        MCollective::PluginManager["connector_plugin"].expects(:unsubscribe).with("test_agent", "test_type", "test_collective").once
        MCollective::PluginManager["connector_plugin"].expects(:unsubscribe).with("test_agent2", "test_type2", "test_collective2").once

        Util.unsubscribe([subs1, subs2])
      end

      it "should subscribe to a single topic given a hash" do
        MCollective::PluginManager["connector_plugin"].expects(:unsubscribe).with("test_agent", "test_type", "test_collective").once
        Util.unsubscribe({:agent => "test_agent", :type => "test_type", :collective => "test_collective"})
      end
    end

    describe "#empty_filter?" do
      it "should correctly compare empty filters" do
        expect(Util.empty_filter?(Util.empty_filter)).to eq(true)
      end

      it "should treat an empty hash as an empty filter" do
        expect(Util.empty_filter?({})).to eq(true)
      end

      it "should detect non empty filters correctly" do
        filter = Util.empty_filter
        filter["cf_class"] << "meh"


        expect(Util.empty_filter?(filter)).to eq(false)
      end
    end

    describe "#empty_filter" do
      it "should create correct empty filters" do
        expect(Util.empty_filter).to eq({"fact" => [], "cf_class" => [], "agent" => [], "identity" => [], "compound" => []})
      end
    end

    describe "#mcollective_config_paths_for_user" do
      it "should support unix" do
        Util.stubs(:windows?).returns(false)

        expect(Util.mcollective_config_paths_for_user).to eq([
          File.expand_path("~/.mcollective"),
          "/etc/puppetlabs/mcollective/client.cfg",
          "/etc/mcollective/client.cfg",
          "/usr/local/etc/mcollective/client.cfg"
        ])
      end

      if Util.windows?
        it "should support windows" do
          Util.stubs(:windows?).returns(true)
          Util.stubs(:choria_windows_prefix).returns("C:/temp")

          expect(Util.choria_config_paths_for_user).to eq([
            File.expand_path("~/.mcollective"),
            File.join("c:/temp", "etc", "client.cfg")
          ])
        end
      end
    end

    describe "#choria_config_paths_for_user" do
      it "should support unix" do
        Util.stubs(:windows?).returns(false)

        expect(Util.choria_config_paths_for_user).to eq([
          File.expand_path("~/.choriarc"),
          "/etc/choria/client.conf",
          "/usr/local/etc/choria/client.conf"
        ])
      end

      if Util.windows?
        it "should support windows" do
          Util.stubs(:windows?).returns(true)
          Util.stubs(:choria_windows_prefix).returns("C:/temp")

          expect(Util.choria_config_paths_for_user).to eq([
            File.expand_path("~/.choriarc"),
            File.join("c:/temp", "etc", "client.conf")
          ])
        end
      end
    end

    describe '#config_file_for_user' do
      it "should pick the first path that exist" do
        Util.expects(:choria_config_paths_for_user).returns(["choria1", "choria2"])
        Util.expects(:mcollective_config_paths_for_user).returns(["mcollective1", "mcollective2"])

        File.expects(:readable?).with("choria1").returns(false)
        File.expects(:readable?).with("choria2").returns(false)
        File.expects(:readable?).with("mcollective1").returns(false)
        File.expects(:readable?).with("mcollective2").returns(true)

        expect(Util.config_file_for_user).to eq("mcollective2")
      end
    end

    describe "#default_options" do
      it "should supply correct default options" do
        Config.instance.stubs(:default_discovery_options).returns([])
        empty_filter = Util.empty_filter
        config_file = Util.config_file_for_user

        expect(Util.default_options).to eq({:verbose => false, :disctimeout => nil, :timeout => 5, :config => config_file, :filter => empty_filter, :collective => nil, :discovery_method => nil, :discovery_options => []})
      end
    end

    describe "#has_fact?" do
      it "should handle missing facts correctly" do
        MCollective::Facts.expects("[]").with("foo").returns(nil).once
        expect(Util.has_fact?("foo", "1", "==")).to eq(false)
      end

      it "should handle regex in a backward compatible way" do
        MCollective::Facts.expects("[]").with("foo").returns("foo").times(6)
        expect(Util.has_fact?("foo", "foo", "=~")).to eq(true)
        expect(Util.has_fact?("foo", "/foo/", "=~")).to eq(true)
        expect(Util.has_fact?("foo", "foo", "=~")).to eq(true)
        expect(Util.has_fact?("foo", "bar", "=~")).to eq(false)
        expect(Util.has_fact?("foo", "/bar/", "=~")).to eq(false)
        expect(Util.has_fact?("foo", "bar", "=~")).to eq(false)
      end

      it "should evaluate equality" do
        MCollective::Facts.expects("[]").with("foo").returns("foo").twice
        expect(Util.has_fact?("foo", "foo", "==")).to eq(true)
        expect(Util.has_fact?("foo", "bar", "==")).to eq(false)
      end

      it "should handle numeric comparisons correctly" do
        MCollective::Facts.expects("[]").with("foo").returns("1").times(8)
        expect(Util.has_fact?("foo", "2", ">=")).to eq(false)
        expect(Util.has_fact?("foo", "1", ">=")).to eq(true)
        expect(Util.has_fact?("foo", "2", "<=")).to eq(true)
        expect(Util.has_fact?("foo", "1", "<=")).to eq(true)
        expect(Util.has_fact?("foo", "1", "<")).to eq(false)
        expect(Util.has_fact?("foo", "1", ">")).to eq(false)
        expect(Util.has_fact?("foo", "1", "!=")).to eq(false)
        expect(Util.has_fact?("foo", "2", "!=")).to eq(true)
      end

      it "should handle alphabetic comparisons correctly" do
        MCollective::Facts.expects("[]").with("foo").returns("b").times(8)
        expect(Util.has_fact?("foo", "c", ">=")).to eq(false)
        expect(Util.has_fact?("foo", "a", ">=")).to eq(true)
        expect(Util.has_fact?("foo", "a", "<=")).to eq(false)
        expect(Util.has_fact?("foo", "b", "<=")).to eq(true)
        expect(Util.has_fact?("foo", "b", "<")).to eq(false)
        expect(Util.has_fact?("foo", "b", ">")).to eq(false)
        expect(Util.has_fact?("foo", "b", "!=")).to eq(false)
        expect(Util.has_fact?("foo", "a", "!=")).to eq(true)
      end

      context 'structured facts (array)' do
        it "should handle regex in a backward compatible way" do
          MCollective::Facts.expects("[]").with("foo").returns(["foo", "baz"]).times(6)
          expect(Util.has_fact?("foo", "foo", "=~")).to eq(true)
          expect(Util.has_fact?("foo", "/foo/", "=~")).to eq(true)
          expect(Util.has_fact?("foo", "foo", "=~")).to eq(true)
          expect(Util.has_fact?("foo", "bar", "=~")).to eq(false)
          expect(Util.has_fact?("foo", "/bar/", "=~")).to eq(false)
          expect(Util.has_fact?("foo", "bar", "=~")).to eq(false)
        end

        it "should evaluate equality" do
          MCollective::Facts.expects("[]").with("foo").returns(["foo", "baz"]).twice
          expect(Util.has_fact?("foo", "foo", "==")).to eq(true)
          expect(Util.has_fact?("foo", "bar", "==")).to eq(false)
        end

        it "should handle numeric comparisons correctly" do
          MCollective::Facts.expects("[]").with("foo").returns(["1"]).times(8)
          expect(Util.has_fact?("foo", "2", ">=")).to eq(false)
          expect(Util.has_fact?("foo", "1", ">=")).to eq(true)
          expect(Util.has_fact?("foo", "2", "<=")).to eq(true)
          expect(Util.has_fact?("foo", "1", "<=")).to eq(true)
          expect(Util.has_fact?("foo", "1", "<")).to eq(false)
          expect(Util.has_fact?("foo", "1", ">")).to eq(false)
          expect(Util.has_fact?("foo", "1", "!=")).to eq(false)
          expect(Util.has_fact?("foo", "2", "!=")).to eq(true)
        end

        it "should handle alphabetic comparisons correctly" do
          MCollective::Facts.expects("[]").with("foo").returns(["b"]).times(8)
          expect(Util.has_fact?("foo", "c", ">=")).to eq(false)
          expect(Util.has_fact?("foo", "a", ">=")).to eq(true)
          expect(Util.has_fact?("foo", "a", "<=")).to eq(false)
          expect(Util.has_fact?("foo", "b", "<=")).to eq(true)
          expect(Util.has_fact?("foo", "b", "<")).to eq(false)
          expect(Util.has_fact?("foo", "b", ">")).to eq(false)
          expect(Util.has_fact?("foo", "b", "!=")).to eq(false)
          expect(Util.has_fact?("foo", "a", "!=")).to eq(true)
        end
      end

      context 'structured facts (hash)' do
        it "should handle regex in a backward compatible way" do
          MCollective::Facts.expects("[]").with("foo").returns({"foo" => 1, "baz" => 2}).times(6)
          expect(Util.has_fact?("foo", "foo", "=~")).to eq(true)
          expect(Util.has_fact?("foo", "/foo/", "=~")).to eq(true)
          expect(Util.has_fact?("foo", "foo", "=~")).to eq(true)
          expect(Util.has_fact?("foo", "bar", "=~")).to eq(false)
          expect(Util.has_fact?("foo", "/bar/", "=~")).to eq(false)
          expect(Util.has_fact?("foo", "bar", "=~")).to eq(false)
        end

        it "should evaluate equality" do
          MCollective::Facts.expects("[]").with("foo").returns({"foo" => 1, "baz" => 2}).twice
          expect(Util.has_fact?("foo", "foo", "==")).to eq(true)
          expect(Util.has_fact?("foo", "bar", "==")).to eq(false)
        end

        it "should handle numeric comparisons correctly" do
          MCollective::Facts.expects("[]").with("foo").returns({"1" => "one"}).times(8)
          expect(Util.has_fact?("foo", "2", ">=")).to eq(false)
          expect(Util.has_fact?("foo", "1", ">=")).to eq(true)
          expect(Util.has_fact?("foo", "2", "<=")).to eq(true)
          expect(Util.has_fact?("foo", "1", "<=")).to eq(true)
          expect(Util.has_fact?("foo", "1", "<")).to eq(false)
          expect(Util.has_fact?("foo", "1", ">")).to eq(false)
          expect(Util.has_fact?("foo", "1", "!=")).to eq(false)
          expect(Util.has_fact?("foo", "2", "!=")).to eq(true)
        end

        it "should handle alphabetic comparisons correctly" do
          MCollective::Facts.expects("[]").with("foo").returns({"b" => 2}).times(8)
          expect(Util.has_fact?("foo", "c", ">=")).to eq(false)
          expect(Util.has_fact?("foo", "a", ">=")).to eq(true)
          expect(Util.has_fact?("foo", "a", "<=")).to eq(false)
          expect(Util.has_fact?("foo", "b", "<=")).to eq(true)
          expect(Util.has_fact?("foo", "b", "<")).to eq(false)
          expect(Util.has_fact?("foo", "b", ">")).to eq(false)
          expect(Util.has_fact?("foo", "b", "!=")).to eq(false)
          expect(Util.has_fact?("foo", "a", "!=")).to eq(true)
        end
      end
    end

    describe 'test_fact_value' do
      it "should handle regex in a backward compatible way" do
        expect(Util.send(:test_fact_value, "foo", "foo", "=~")).to eq(true)
        expect(Util.send(:test_fact_value, "foo", "/foo/", "=~")).to eq(true)
        expect(Util.send(:test_fact_value, "foo", "foo", "=~")).to eq(true)
        expect(Util.send(:test_fact_value, "foo", "bar", "=~")).to eq(false)
        expect(Util.send(:test_fact_value, "foo", "/bar/", "=~")).to eq(false)
        expect(Util.send(:test_fact_value, "foo", "bar", "=~")).to eq(false)
      end

      it "should evaluate equality" do
        expect(Util.send(:test_fact_value, "foo", "foo", "==")).to eq(true)
        expect(Util.send(:test_fact_value, "foo", "bar", "==")).to eq(false)
      end

      it "should handle numeric comparisons correctly" do
        expect(Util.send(:test_fact_value, "1", "2", ">=")).to eq(false)
        expect(Util.send(:test_fact_value, "1", "1", ">=")).to eq(true)
        expect(Util.send(:test_fact_value, "1", "2", "<=")).to eq(true)
        expect(Util.send(:test_fact_value, "1", "1", "<=")).to eq(true)
        expect(Util.send(:test_fact_value, "1", "1", "<")).to eq(false)
        expect(Util.send(:test_fact_value, "1", "1", ">")).to eq(false)
        expect(Util.send(:test_fact_value, "1", "1", "!=")).to eq(false)
        expect(Util.send(:test_fact_value, "1", "2", "!=")).to eq(true)
        expect(Util.send(:test_fact_value, "100", "2", ">")).to eq(true)
        expect(Util.send(:test_fact_value, "100", "2", ">=")).to eq(true)
        expect(Util.send(:test_fact_value, "100", "2", "<")).to eq(false)
        expect(Util.send(:test_fact_value, "100", "2", "<=")).to eq(false)
      end

      it "should handle alphabetic comparisons correctly" do
        expect(Util.send(:test_fact_value, "b", "c", ">=")).to eq(false)
        expect(Util.send(:test_fact_value, "b", "a", ">=")).to eq(true)
        expect(Util.send(:test_fact_value, "b", "a", "<=")).to eq(false)
        expect(Util.send(:test_fact_value, "b", "b", "<=")).to eq(true)
        expect(Util.send(:test_fact_value, "b", "b", "<")).to eq(false)
        expect(Util.send(:test_fact_value, "b", "b", ">")).to eq(false)
        expect(Util.send(:test_fact_value, "b", "b", "!=")).to eq(false)
        expect(Util.send(:test_fact_value, "b", "a", "!=")).to eq(true)
      end
    end


    describe "#parse_fact_string" do
      it "should parse old style regex fact matches" do
        expect(Util.parse_fact_string("foo=/bar/")).to eq({:fact => "foo", :value => "/bar/", :operator => "=~"})
        expect(Util.parse_fact_string("foo = /bar/")).to eq({:fact => "foo", :value => "/bar/", :operator => "=~"})
      end

      it "should parse old style equality" do
        expect(Util.parse_fact_string("foo=bar")).to eq({:fact => "foo", :value => "bar", :operator => "=="})
        expect(Util.parse_fact_string("foo = bar")).to eq({:fact => "foo", :value => "bar", :operator => "=="})
      end

      it "should parse regex fact matches" do
        expect(Util.parse_fact_string("foo=~bar")).to eq({:fact => "foo", :value => "bar", :operator => "=~"})
        expect(Util.parse_fact_string("foo =~ bar")).to eq({:fact => "foo", :value => "bar", :operator => "=~"})
      end

      it "should treat => like >=" do
        expect(Util.parse_fact_string("foo=>bar")).to eq({:fact => "foo", :value => "bar", :operator => ">="})
        expect(Util.parse_fact_string("foo => bar")).to eq({:fact => "foo", :value => "bar", :operator => ">="})
      end

      it "should treat =< like <=" do
        expect(Util.parse_fact_string("foo=<bar")).to eq({:fact => "foo", :value => "bar", :operator => "<="})
        expect(Util.parse_fact_string("foo =< bar")).to eq({:fact => "foo", :value => "bar", :operator => "<="})
      end

      it "should parse less than or equal" do
        expect(Util.parse_fact_string("foo<=bar")).to eq({:fact => "foo", :value => "bar", :operator => "<="})
        expect(Util.parse_fact_string("foo <= bar")).to eq({:fact => "foo", :value => "bar", :operator => "<="})
      end

      it "should parse greater than or equal" do
        expect(Util.parse_fact_string("foo>=bar")).to eq({:fact => "foo", :value => "bar", :operator => ">="})
        expect(Util.parse_fact_string("foo >= bar")).to eq({:fact => "foo", :value => "bar", :operator => ">="})
      end

      it "should parse less than" do
        expect(Util.parse_fact_string("foo<bar")).to eq({:fact => "foo", :value => "bar", :operator => "<"})
        expect(Util.parse_fact_string("foo < bar")).to eq({:fact => "foo", :value => "bar", :operator => "<"})
      end

      it "should parse greater than" do
        expect(Util.parse_fact_string("foo>bar")).to eq({:fact => "foo", :value => "bar", :operator => ">"})
        expect(Util.parse_fact_string("foo > bar")).to eq({:fact => "foo", :value => "bar", :operator => ">"})
      end

      it "should parse greater than" do
        expect(Util.parse_fact_string("foo>bar")).to eq({:fact => "foo", :value => "bar", :operator => ">"})
        expect(Util.parse_fact_string("foo > bar")).to eq({:fact => "foo", :value => "bar", :operator => ">"})
      end

      it "should parse not equal" do
        expect(Util.parse_fact_string("foo!=bar")).to eq({:fact => "foo", :value => "bar", :operator => "!="})
        expect(Util.parse_fact_string("foo != bar")).to eq({:fact => "foo", :value => "bar", :operator => "!="})
      end

      it "should parse equal to" do
        expect(Util.parse_fact_string("foo==bar")).to eq({:fact => "foo", :value => "bar", :operator => "=="})
        expect(Util.parse_fact_string("foo == bar")).to eq({:fact => "foo", :value => "bar", :operator => "=="})
      end

      it "should fail for facts in the wrong format" do
        expect {
          Util.parse_fact_string("foo")
        }.to raise_error("Could not parse fact foo it does not appear to be in a valid format")
      end
    end

    describe "#colorize" do
      it "should not add color codes when color is disabled" do
        Config.instance.stubs(:color).returns(false)
        expect(Util.colorize(:red, "hello world")).to eq("hello world")
      end

      it "should add color when color is enabled" do
        Config.instance.stubs(:color).returns(true)
        expect(Util.colorize(:red, "hello world")).to eq("[31mhello world[0m")
      end
    end

    describe "#align_text" do
      it "should default to 80 if the terminal dimensions are unknown" do
        Util.stubs(:terminal_dimensions).returns([0,0])

        rootdir = File.dirname(__FILE__)
        input = File.read("#{rootdir}/../../fixtures/util/4.in")
        output = File.read("#{rootdir}/../../fixtures/util/4.out")

        expect(Util.align_text(input, nil, 3) + "\n").to eq(output)
      end

      it "should return the origional string if console lines are 0" do
        result = Util.align_text("test", 0)
        expect(result).to eq("test")
      end

      it "should return the origional string if preamble is greater than console lines" do
        result = Util.align_text("test", 5, 6)
        expect(result).to eq("test")
      end

      it "should return a string prefixed by the preamble" do
        result = Util.align_text("test")
        expect(result).to eq("     test")
      end

      it "should correctly align strings" do
        rootdir = File.dirname(__FILE__)
        (1..2).each do |i|
          input = File.read("#{rootdir}/../../fixtures/util/#{i}.in")
          output = File.read("#{rootdir}/../../fixtures/util/#{i}.out")

          expect(Util.align_text(input, 158 , 5) + "\n").to eq(output)
        end

        input = File.read("#{rootdir}/../../fixtures/util/3.in")
        output = File.read("#{rootdir}/../../fixtures/util/3.out")

        expect(Util.align_text(input, 30, 0) + "\n").to eq(output)
      end
    end

    describe "#terminal_dimensions" do
      it "should return 0 if there is no tty" do
        stdout = mock()
        stdout.expects(:tty?).returns(false)
        result = Util.terminal_dimensions(stdout)
        expect(result).to eq([0,0])
      end

      it "should return the default dimensions for a windows terminal" do
        stdout = mock()
        stdout.expects(:tty?).returns(true)
        Util.expects(:windows?).returns(true)
        result = Util.terminal_dimensions(stdout)
        expect(result).to eq([80, 40])
      end

      it "should return 0 if an exception was raised" do
        stdout = mock()
        stdout.expects(:tty?).raises("error")
        result = Util.terminal_dimensions(stdout)
        expect(result).to eq([0, 0])
      end

      it "should return the correct dimensions if ENV columns and lines are set" do
        stdout = mock()
        stdout.expects(:tty?).returns(true)
        Util.expects(:windows?).returns(false)
        environment = mock()
        environment.expects(:[]).with("COLUMNS").returns(5).twice
        environment.expects(:[]).with("LINES").returns(5).twice
        result = Util.terminal_dimensions(stdout, environment)
        expect(result).to eq([5,5])
      end

      it "should return the correct dimensions if ENV term is set and tput is present" do
        stdout = mock()
        stdout.expects(:tty?).returns(true)
        Util.expects(:windows?).returns(false)
        environment = mock()
        environment.expects(:[]).with("COLUMNS").returns(false)
        environment.expects(:[]).with("TERM").returns(true)

        Util.expects(:command_in_path?).with("tput").returns(true)
        Util.stubs(:`).returns("5")

        result = Util.terminal_dimensions(stdout, environment)
        expect(result).to eq([5,5])
      end

      it "should return the correct dimensions if stty is present" do
        stdout = mock()
        stdout.expects(:tty?).returns(true)
        Util.expects(:windows?).returns(false)

        environment = mock()
        environment.expects(:[]).with("COLUMNS").returns(false)
        environment.expects(:[]).with("TERM").returns(false)

        Util.expects(:command_in_path?).with("stty").returns(true)
        Util.stubs(:`).returns("5 5")

        result = Util.terminal_dimensions(stdout, environment)
        expect(result).to eq([5,5])
      end
    end

    describe "#command_in_path?" do
      it "should return true if the command is found" do
        File.stubs(:exist?).returns(true)
        result = Util.command_in_path?("test")
        expect(result).to eq(true)
      end

      it "should return false if the command cannot be found" do
        File.stubs(:exist?).returns(false)
        result = Util.command_in_path?("test")
        expect(result).to eq(false)
      end
    end

    describe "#absolute_path?" do
      it "should work correctly validate the path" do
        expect(Util.absolute_path?('.', '/', '\\')).to eq(false)
        expect(Util.absolute_path?('foo/foo', '/', '\\')).to eq(false)
        expect(Util.absolute_path?('foo\\bar', '/', '\\')).to eq(false)
        expect(Util.absolute_path?('../foo/bar', '/', '\\')).to eq(false)

        expect(Util.absolute_path?('\\foo/foo', '/', '\\')).to eq(true)
        expect(Util.absolute_path?('\\', '/', '\\')).to eq(true)
        expect(Util.absolute_path?('/foo', '/', '\\')).to eq(true)
        expect(Util.absolute_path?('/foo/foo', '/', '\\')).to eq(true)

        expect(Util.absolute_path?('.', '/', nil)).to eq(false)
        expect(Util.absolute_path?('foo/foo', '/', nil)).to eq(false)
        expect(Util.absolute_path?('foo\\bar', '/', nil)).to eq(false)
        expect(Util.absolute_path?('../foo/bar', '/', nil)).to eq(false)

        expect(Util.absolute_path?('\\foo/foo', '/', nil)).to eq(false)
        expect(Util.absolute_path?('\\', '/', nil)).to eq(false)
        expect(Util.absolute_path?('/foo', '/', nil)).to eq(true)
        expect(Util.absolute_path?('/foo/foo', '/', nil)).to eq(true)
      end

      it "should correctly validate paths on Windows" do
        ['C:\foo', '\foo\bar', '\C\FOO\Bar', '/C/FOO/Bar'].each do |path|
          expect(Util.absolute_path?(path, '/', '\\')).to be_truthy
        end
      end
    end

    describe "#versioncmp" do
      it "should be able to sort a long set of various unordered versions" do
        ary = %w{ 1.1.6 2.3 1.1a 3.0 1.5 1 2.4 1.1-4 2.3.1 1.2 2.3.0 1.1-3 2.4b 2.4 2.40.2 2.3a.1 3.1 0002 1.1-5 1.1.a 1.06 1.2.10 1.2.8}

        newary = ary.sort {|a, b| Util.versioncmp(a,b) }

        expect(newary).to eq(["0002", "1", "1.06", "1.1-3", "1.1-4", "1.1-5", "1.1.6", "1.1.a", "1.1a", "1.2", "1.2.8", "1.2.10", "1.5", "2.3", "2.3.0", "2.3.1", "2.3a.1", "2.4", "2.4", "2.4b", "2.40.2", "3.0", "3.1"])
      end
    end

    describe "str_to_bool" do
      it "should transform true like strings into TrueClass" do
        ["1", "y", "yes", "Y", "YES", "t", "true", "T", "TRUE", true].each do |val|
          expect(Util.str_to_bool(val)).to be_truthy
        end
      end

      it "should transform false like strings into FalseClass" do
        ["0", "n", "no", "N", "NO", "f", "false", "F", "FALSE", false].each do |val|
          expect(Util.str_to_bool(val)).to be_falsey
        end
      end

      it "should raise an exception if the string does not match the boolean pattern" do
        ["yep", "nope", "yess", "noway", "rspec", "YES!", "NO?"].each do |val|
          expect { Util.str_to_bool(val) }.to raise_error("Cannot convert string value '#{val}' into a boolean.")
        end
      end
    end

    describe "#templatepath" do
      before do
        config = mock
        config.stubs(:configfile).returns("/rspec/server.cfg")
        Config.stubs(:instance).returns(config)
      end
      it "should look for a template in the config dir" do
        File.stubs(:exist?).with("/rspec/test-help.erb").returns(true)
        expect(Util.templatepath("test-help.erb")).to eq("/rspec/test-help.erb")
      end

      it "should look for a template in the default dir" do
        File.stubs(:exist?).with("/rspec/test-help.erb").returns(false)
        File.stubs(:exist?).with("/etc/mcollective/test-help.erb").returns(true)
        expect(Util.templatepath("test-help.erb")).to eq("/etc/mcollective/test-help.erb")

      end
    end

    describe "#field_size" do
      context "when elements are smaller than min_size" do
        it "should return min_size" do
          expect(Util.field_size(['abc', 'def'])).to eq(40)
        end
      end

      context "when elements are bigger than min_size" do
        it "should return the size of the biggest element" do
          expect(Util.field_size(['abc', 'def'], 2)).to eq(3)
        end
      end
    end

    describe "#field_number" do
      context "when field size is smaller than max_size" do
        it "should return field number" do
          expect(Util.field_number(30)).to eq(3)
        end
      end

      context "when field size is smaller than max_size" do
        it "should return 1" do
          expect(Util.field_number(100)).to eq(1)
        end
      end

      context "when specifying max_size" do
        it "should adapt to max_size" do
          expect(Util.field_number(30, 70)).to eq(2)
        end
      end
    end
  end
end
