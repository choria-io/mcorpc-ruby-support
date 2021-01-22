#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe Config do
    describe "#project_config_files" do
      it "should find the correct configs" do
        paths = Config.instance.project_config_files(File.join("spec", "fixtures", "config", "project", "project2"))

        pwd = Dir.pwd
        expect(paths[-1]).to eq(File.join(pwd, "spec", "fixtures", "config", "project","project2","choria.conf"))
        expect(paths[-2]).to eq(File.join(pwd, "spec", "fixtures", "config", "project", "choria.conf"))
      end

      it "Should override already loaded configs" do
        pwd = Dir.pwd
        cfg = File.join(pwd, "spec", "fixtures", "config", "client.conf")
        p1 = File.join(pwd, "spec","fixtures","config","project")
        p2 = File.join(p1, "project2")

        Config.instance.stubs(:project_root).returns(p2)
        Config.instance.loadconfig(cfg)
        expect(Config.instance.pluginconf).to eq({"project" => "2"})
        expect(Config.instance.loglevel).to eq("debug")

        Config.instance.stubs(:project_root).returns(p1)
        Config.instance.loadconfig(cfg)
        expect(Config.instance.pluginconf).to eq({"project" => "1"})
        expect(Config.instance.loglevel).to eq("info")

        Config.instance.stubs(:project_root).returns("/nonexisting")
        Config.instance.loadconfig(cfg)
        expect(Config.instance.pluginconf).to eq({"project" => "0"})
        expect(Config.instance.loglevel).to eq("info")
      end
    end

    describe "#loadconfig" do
      it "should only test that libdirs are absolute paths" do
        Util.expects(:absolute_path?).with("/one").returns(true)
        Util.expects(:absolute_path?).with("/two").returns(true)
        Util.expects(:absolute_path?).with("/three").returns(true)
        Util.expects(:absolute_path?).with("four").returns(false)

        File.stubs(:exist?).with("/nonexisting").returns(true)
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")

        ["/one#{File::PATH_SEPARATOR}/two", "/three"].each do |path|
          File.expects(:readlines).with("/nonexisting").returns(["libdir = #{path}"])

          Config.instance.loadconfig("/nonexisting")

          PluginManager.clear
        end

        File.expects(:readlines).with("/nonexisting").returns(["libdir = four"])

        expect { Config.instance.loadconfig("/nonexisting") }.to raise_error(/should be absolute paths/)
      end

      it 'should prepend $libdir to $LOAD_PATH' do
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")
        Util.expects(:absolute_path?).with('/test').returns(true)

        File.stubs(:exist?).with("/nonexisting").returns(true)

        File.expects(:readlines).with('/nonexisting').returns(['libdir = /test'])

        Config.instance.loadconfig("/nonexisting")

        expect($LOAD_PATH[0]).to eq('/test')
      end

      it "should not allow any path like construct for identities" do
        # Taken from puppet test cases
        ['../foo', '..\\foo', './../foo', '.\\..\\foo',
          '/foo', '//foo', '\\foo', '\\\\goo',
          "test\0/../bar", "test\0\\..\\bar",
          "..\\/bar", "/tmp/bar", "/tmp\\bar", "tmp\\bar",
          " / bar", " /../ bar", " \\..\\ bar",
          "c:\\foo", "c:/foo", "\\\\?\\UNC\\bar", "\\\\foo\\bar",
          "\\\\?\\c:\\foo", "//?/UNC/bar", "//foo/bar",
          "//?/c:/foo"
        ].each do |input|
          File.expects(:readlines).with("/nonexisting").returns(["identity = #{input}", "libdir=/nonexistinglib"])
          File.expects(:exist?).with("/nonexisting").returns(true)
          File.stubs(:exist?).with("/choria.conf").returns(false)
          Config.instance.stubs(:project_root).returns("/")

          expect {
            Config.instance.loadconfig("/nonexisting")
          }.to raise_error('Identities can only match /\w\.\-/')
        end
      end

      it "should strip whitespaces from config keys" do
        File.expects(:exist?).with("/nonexisting").returns(true)
        File.expects(:readlines).with("/nonexisting").returns([" identity= your.example.com  ", "libdir=/nonexisting"])
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")

        config = Config.instance
        config.loadconfig("/nonexisting")
        expect(config.identity).to eq("your.example.com")
      end

      it "should allow valid identities" do
        ["foo", "foo_bar", "foo-bar", "foo-bar-123", "foo.bar", "foo_bar_123"].each do |input|
          File.stubs(:exist?).with("/choria.conf").returns(false)
          Config.instance.stubs(:project_root).returns("/")
          File.expects(:readlines).with("/nonexisting").returns(["identity = #{input}", "libdir=/nonexistinglib"])
          File.expects(:exist?).with("/nonexisting").returns(true)
          PluginManager.stubs(:loadclass)
          PluginManager.stubs("<<")

          Config.instance.loadconfig("/nonexisting")
        end
      end

      it "should set direct_addressing to true by default" do
        File.expects(:readlines).with("/nonexisting").returns(["libdir=/nonexistinglib"])
        File.expects(:exist?).with("/nonexisting").returns(true)
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")
        PluginManager.stubs(:loadclass)
        PluginManager.stubs("<<")

        Config.instance.loadconfig("/nonexisting")
        expect(Config.instance.direct_addressing).to eq(true)
      end

      it "should allow direct_addressing to be disabled in the config file" do
        File.expects(:readlines).with("/nonexisting").returns(["libdir=/nonexistinglib", "direct_addressing=n"])
        File.expects(:exist?).with("/nonexisting").returns(true)
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")
        PluginManager.stubs(:loadclass)
        PluginManager.stubs("<<")

        Config.instance.loadconfig("/nonexisting")
        expect(Config.instance.direct_addressing).to eq(false)
      end

      it "should not allow the syslog logger type on windows" do
        Util.expects("windows?").returns(true).twice
        File.expects(:readlines).with("/nonexisting").returns(["libdir=/nonexistinglib", "logger_type=syslog"])
        File.expects(:exist?).with("/nonexisting").returns(true)
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")
        PluginManager.stubs(:loadclass)
        PluginManager.stubs("<<")

        expect { Config.instance.loadconfig("/nonexisting") }.to raise_error("The sylog logger is not usable on the Windows platform")
      end

      it "should support multiple default_discovery_options" do
        File.expects(:readlines).with("/nonexisting").returns(["default_discovery_options = 1", "default_discovery_options = 2", "libdir=/nonexistinglib"])
        File.expects(:exist?).with("/nonexisting").returns(true)
        PluginManager.stubs(:loadclass)
        PluginManager.stubs("<<")
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")

        Config.instance.loadconfig("/nonexisting")
        expect(Config.instance.default_discovery_options).to eq(["1", "2"])
      end

      it "should not allow non integer values when expecting an integer value" do
        PluginManager.stubs(:loadclass)
        PluginManager.stubs("<<")
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")

        ["max_log_size", "direct_addressing_threshold", "publish_timeout", "fact_cache_time", "ttl"].each do |key|
          File.expects(:readlines).with("/nonexisting").returns(["#{key} = nan"])
          File.expects(:exist?).with("/nonexisting").returns(true)

          expect{
            Config.instance.loadconfig("/nonexisting")
          }.to raise_error "Could not parse value for configuration option '#{key}' with value 'nan'"
         end
      end

      it 'should enable agents by default' do
        File.expects(:readlines).with("/nonexisting").returns(["libdir=/nonexistinglib"])
        File.expects(:exist?).with("/nonexisting").returns(true)
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")
        PluginManager.stubs(:loadclass)
        PluginManager.stubs("<<")

        Config.instance.loadconfig("/nonexisting")
        expect(Config.instance.activate_agents).to eq(true)
      end
    end

    describe "#read_plugin_config_dir" do
      before do
        @plugindir = File.join("/", "nonexisting", "plugin.d")

        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")
        File.stubs(:directory?).with(@plugindir).returns(true)

        Config.instance.set_config_defaults("")
      end

      it "should not fail if the supplied directory is missing" do
        File.expects(:directory?).with(@plugindir).returns(false)
        Config.instance.read_plugin_config_dir(@plugindir)
        expect(Config.instance.pluginconf).to eq({})
      end

      it "should skip files that do not match the expected filename pattern" do
        Dir.expects(:new).with(@plugindir).returns(["foo.txt"])

        File.expects(:open).with(File.join(@plugindir, "foo.txt")).never

        Config.instance.read_plugin_config_dir(@plugindir)
      end

      it "should load the config files" do
        Dir.expects(:new).with(@plugindir).returns(["foo.cfg"])
        File.expects(:open).with(File.join(@plugindir, "foo.cfg"), "r").returns([]).once
        Config.instance.read_plugin_config_dir(@plugindir)
      end

      it "should set config parameters correctly" do
        Dir.expects(:new).with(@plugindir).returns(["foo.cfg"])
        File.expects(:open).with(File.join(@plugindir, "foo.cfg"), "r").returns(["rspec = test"])
        Config.instance.read_plugin_config_dir(@plugindir)
        expect(Config.instance.pluginconf).to eq({"foo.rspec" => "test"})
      end

      it "should strip whitespaces from config keys" do
        Dir.expects(:new).with(@plugindir).returns(["foo.cfg"])
        File.expects(:open).with(File.join(@plugindir, "foo.cfg"), "r").returns(["   rspec  = test"])
        Config.instance.read_plugin_config_dir(@plugindir)
        expect(Config.instance.pluginconf).to eq({"foo.rspec" => "test"})
      end

      it "should override main config file" do
        configfile = File.join(@plugindir, "foo.cfg")
        servercfg = File.join(File.dirname(@plugindir), "server.cfg")

        PluginManager.stubs(:loadclass)

        File.stubs(:exist?).returns(true)
        File.stubs(:directory?).with(@plugindir).returns(true)
        File.stubs(:exist?).with(servercfg).returns(true)
        File.expects(:readlines).with(servercfg).returns(["plugin.rspec.key = default", "libdir=/nonexisting"])
        File.stubs(:directory?).with("/nonexisting").returns(true)

        Dir.expects(:new).with(@plugindir).returns(["rspec.cfg"])
        File.expects(:open).with(File.join(@plugindir, "rspec.cfg"), "r").returns(["key = overridden"])
        File.stubs(:exist?).with("/choria.conf").returns(false)
        Config.instance.stubs(:project_root).returns("/")

        Config.instance.loadconfig(servercfg)
        expect(Config.instance.pluginconf).to eq({"rspec.key" => "overridden"})
      end
    end
  end
end
