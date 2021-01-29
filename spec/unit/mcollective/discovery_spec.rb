#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe Discovery do
    before do
      Config.instance.stubs(:default_discovery_method).returns("mc")
      @client = mock

      Discovery.any_instance.stubs(:find_known_methods).returns(["mc"])
      @discovery = Discovery.new(@client)
    end

    describe "#discover" do
      before do
        ddl = mock
        ddl.stubs(:meta).returns({:timeout => 2})

        discoverer = mock

        @discovery.stubs(:force_discovery_method_by_filter).returns(false)
        @discovery.stubs(:ddl).returns(ddl)
        @discovery.stubs(:check_capabilities)
        @discovery.stubs(:discovery_class).returns(discoverer)
      end

      it "should error for non fixnum limits" do
        expect { @discovery.discover(nil, 0, 1.1, @client) }.to raise_error("Limit has to be an integer")
      end

      it "should use the DDL timeout if none is specified" do
        filter = Util.empty_filter
        @discovery.discovery_class.expects(:discover).with(filter, 2, 0, @client)
        @discovery.discover(filter, nil, 0, @client)
      end

      it "should call the correct discovery plugin" do
        @discovery.discovery_class.expects(:discover).with("filter", 2, 0, @client)
        @discovery.discover("filter", nil, 0, @client)
      end

      it "should handle limits correctly" do
        @discovery.discovery_class.stubs(:discover).returns([1,2,3,4,5])
        expect(@discovery.discover(Util.empty_filter, 1, 1, @client)).to eq([1])
        expect(@discovery.discover(Util.empty_filter, 1, 0, @client)).to eq([1,2,3,4,5])
      end
    end

    describe "#ddl" do
      before do
        @ddl = mock
        @ddl.stubs(:meta).returns({:name => "mc"})
      end

      it "should create an instance of the right ddl" do
        @discovery.instance_variable_set("@ddl", nil)
        @client.stubs(:options).returns({})
        DDL.expects(:new).with("mc", :discovery).returns(@ddl)
        @discovery.ddl
      end

      it "should reload the ddl if the method has changed" do
        @discovery.instance_variable_set("@ddl", @ddl)
        @discovery.stubs(:discovery_method).returns("rspec")
        DDL.expects(:new).with("rspec", :discovery).returns(@ddl)
        @discovery.ddl
      end
    end

    describe "#initialize" do
      it "should load all the known methods" do
        expect(@discovery.find_known_methods).to eq(["mc"])
      end
    end

    describe "#find_known_methods" do
      it "should use the PluginManager to find plugins of type 'discovery'" do
        expect(@discovery.find_known_methods).to eq(["mc"])
      end
    end

    describe "#has_method?" do
      it "should correctly report the availability of a discovery method" do
        expect(@discovery.has_method?("mc")).to eq(true)
        expect(@discovery.has_method?("rspec")).to eq(false)
      end
    end

    describe "#discovery_method" do
      it "should default to 'mc'" do
        @client.expects(:options).returns({})
        expect(@discovery.discovery_method).to eq("mc")
      end

      it "should give preference to the client options" do
        @client.expects(:options).returns({:discovery_method => "rspec"}).twice
        Config.instance.expects(:direct_addressing).returns(true)
        @discovery.expects(:has_method?).with("rspec").returns(true)
        expect(@discovery.discovery_method).to eq("rspec")
      end

      it "should validate the discovery method exists" do
        @client.expects(:options).returns({:discovery_method => "rspec"}).twice
        expect { expect(@discovery.discovery_method).to eq("rspec") }.to raise_error("Unknown discovery method rspec")
      end

      it "should only allow custom discovery methods if direct_addressing is enabled" do
        @client.expects(:options).returns({:discovery_method => "rspec"}).twice
        Config.instance.expects(:direct_addressing).returns(false)
        @discovery.expects(:has_method?).with("rspec").returns(true)
        expect { expect(@discovery.discovery_method).to eq("rspec") }.to raise_error("Custom discovery methods require direct addressing mode")
      end
    end
  end
end
