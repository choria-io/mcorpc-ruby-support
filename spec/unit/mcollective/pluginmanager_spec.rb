#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe PluginManager do
    before do
      class MCollective::Foo; end

      PluginManager.pluginlist.each {|p| PluginManager.delete p}
      @config = mock
    end

    describe "#<<" do
      it "should store a plugin by name" do
        PluginManager << {:type => "foo", :class => "MCollective::Foo"}
        expect(PluginManager.instance_variable_get("@plugins").include?("foo")).to eq(true)
      end

      it "should store a plugin instance" do
        f = MCollective::Foo.new

        PluginManager << {:type => "foo", :class => f}
        expect(PluginManager.instance_variable_get("@plugins")["foo"][:instance].object_id).to eq(f.object_id)
      end

      it "should detect duplicate plugins" do
        PluginManager << {:type => "foo", :class => "MCollective::Foo"}

        expect {
          PluginManager << {:type => "foo", :class => "MCollective::Foo"}
        }.to raise_error("Plugin foo already loaded")
      end

      it "should store single instance preference correctly" do
        PluginManager << {:type => "foo", :class => "MCollective::Foo", :single_instance => false}
        expect(PluginManager.instance_variable_get("@plugins")["foo"][:single]).to eq(false)
      end

      it "should always set single to true when supplied an instance" do
        PluginManager << {:type => "foo", :class => MCollective::Foo.new, :single_instance => false}
        expect(PluginManager.instance_variable_get("@plugins")["foo"][:single]).to eq(true)
      end
    end

    describe "#delete" do
      it "should remove plugins" do
        PluginManager << {:type => "foo", :class => MCollective::Foo.new}
        expect(PluginManager.instance_variable_get("@plugins").include?("foo")).to eq(true)
        PluginManager.delete("foo")
        expect(PluginManager.instance_variable_get("@plugins").include?("foo")).to eq(false)
      end
    end

    describe "#include?" do
      it "should correctly check if plugins were added" do
        PluginManager << {:type => "foo", :class => MCollective::Foo.new}
        expect(PluginManager.include?("foo")).to eq(true)
        expect(PluginManager.include?("bar")).to eq(false)
      end
    end

    describe "#pluginlist" do
      it "should return the correct list of plugins" do
        PluginManager << {:type => "foo", :class => MCollective::Foo.new}
        PluginManager << {:type => "bar", :class => MCollective::Foo.new}

        expect(PluginManager.pluginlist.sort).to eq(["bar", "foo"])
      end
    end

    describe "#[]" do
      it "should detect if the requested plugin does not exist" do
        expect {
          PluginManager["foo"]
        }.to raise_error("No plugin foo defined")
      end

      it "should create new instances on demand" do
        PluginManager << {:type => "foo", :class => "MCollective::Foo"}
        expect(PluginManager["foo"].class).to eq(MCollective::Foo)
      end

      it "should return the cached instance" do
        f = MCollective::Foo.new

        PluginManager << {:type => "foo", :class => f}
        expect(PluginManager["foo"].object_id).to eq(f.object_id)
      end

      it "should create new instances on every request if requested" do
        PluginManager << {:type => "foo", :class => "MCollective::Foo", :single_instance => false}
        expect(PluginManager["foo"].object_id).not_to eq(PluginManager["foo"].object_id)
      end
    end

    describe "#find" do
      before do
        @config.stubs(:libdir).returns(["/libdir/"])
        Config.stubs(:instance).returns(@config)
      end

      it "should find all plugins in configured libdirs" do
        File.expects(:join).with(["/libdir/", "mcollective", "test"]).returns("/plugindir/")
        File.expects(:directory?).with("/plugindir/").returns(true)
        Dir.expects(:new).with("/plugindir/").returns(["plugin.rb"])
        expect(PluginManager.find("test")).to eq(["plugin"])
      end

      it "should find all plugins with a given file extension" do
        File.expects(:join).with(["/libdir/", "mcollective", "test"]).returns("/plugindir/")
        File.expects(:directory?).with("/plugindir/").returns(true)
        Dir.expects(:new).with("/plugindir/").returns(["plugin.ddl"])
        expect(PluginManager.find("test", "ddl")).to eq(["plugin"])
      end

      it "should skip libdirs that do not have the plugin type directories" do
        @config.stubs(:libdir).returns(["/plugindir/", "/tmp/"])
        File.expects(:join).with(["/plugindir/", "mcollective", "test"]).returns("/plugindir/")
        File.expects(:join).with(["/tmp/", "mcollective", "test"]).returns("/tmpdir/")
        File.expects(:directory?).with("/plugindir/").returns(true)
        File.expects(:directory?).with("/tmpdir/").returns(false)
        Dir.expects(:new).with("/plugindir/").returns(["plugin.ddl"])
        expect(PluginManager.find("test", "ddl")).to eq(["plugin"])
      end
    end

    describe "#find_and_load" do
      before do
        @config.stubs(:libdir).returns(["/libdir/"])
        Config.stubs(:instance).returns(@config)
        PluginManager.expects(:loadclass).with("MCollective::Test::Testplugin", true)
      end

      it "should find and load all plugins from all libdirs that match the type" do
        PluginManager.expects(:find).with("test", ".rb").returns(["testplugin"])
        PluginManager.find_and_load("test")
      end

      it "should exclude plugins who do not match criteria if block is given" do
        PluginManager.expects(:find).with("test", ".rb").returns(["testplugin", "failplugin"])
        PluginManager.find_and_load("test") {|plugin| plugin.match(/^test/)}
      end
    end

    describe "#loadclass" do
      it "should load the correct filename given a ruby class name" do
        PluginManager.stubs(:load).with("mcollective/foo.rb").once
        PluginManager.loadclass("MCollective::Foo")
      end

      it "should raise errors for load errors" do
        PluginManager.stubs(:load).raises("load failure")
        Log.expects(:error)
        expect { PluginManager.loadclass("foo") }.to raise_error(/load failure/)
      end

      it "should support squashing load errors" do
        PluginManager.stubs(:load).raises("load failure")
        Log.expects(:error)
        PluginManager.loadclass("foo", true)
      end
    end

    describe "#grep" do
      it "should return matching plugins from the list" do
        PluginManager << {:type => "foo", :class => MCollective::Foo.new}
        PluginManager << {:type => "bar", :class => MCollective::Foo.new}

        expect(PluginManager.grep(/oo/)).to eq(["foo"])
      end
    end
  end
end
