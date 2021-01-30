#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe Optionparser do
    describe "#initialize" do
      it "should store the included list as an array" do
        parser = Optionparser.new({}, "included")
        expect(parser.instance_variable_get("@include")).to eq(["included"])

        parser = Optionparser.new({}, ["included"])
        expect(parser.instance_variable_get("@include")).to eq(["included"])
      end

      it "should store the excluded list as an array" do
        parser = Optionparser.new({}, "", "excluded")
        expect(parser.instance_variable_get("@exclude")).to eq(["excluded"])

        parser = Optionparser.new({}, "", ["excluded"])
        expect(parser.instance_variable_get("@exclude")).to eq(["excluded"])
      end

      it "should gather default options" do
        Util.expects(:default_options).returns({})
        Optionparser.new({})
      end

      it "should merge supplied options with defaults" do
        defaults = {}
        supplied = {}

        Util.expects(:default_options).returns(defaults)
        defaults.expects(:merge!).with(supplied)

        Optionparser.new(supplied)
      end
    end

    describe "#parse" do
      it "should yield to the caller" do
        parser = Optionparser.new(defaults={:default => 1})

        block_ran = false

        parser.parse do |p, o|
          expect(p.class).to eq(OptionParser)
          expect(o).to eq(Util.default_options.merge(defaults))
          block_ran = true
        end

        expect(block_ran).to eq(true)
      end

      it "should add required options" do
        parser = Optionparser.new(defaults={:default => 1})
        parser.expects(:add_required_options)
        parser.parse
      end

      it "should optionally add common options" do
        parser = Optionparser.new(defaults={:default => 1})
        parser.stubs(:add_required_options)
        parser.expects(:add_common_options)
        parser.parse

        parser = Optionparser.new(defaults={:default => 1}, "", "common")
        parser.stubs(:add_required_options)
        parser.expects(:add_common_options).never
        parser.parse
      end

      it "should support adding arbitrary named sections of options" do
        parser = Optionparser.new(defaults={:default => 1}, "filter")
        parser.stubs(:add_required_options)
        parser.stubs(:add_common_options)
        parser.expects(:add_filter_options)
        parser.parse
      end

      it "should support excluding sections that was specifically included" do
        parser = Optionparser.new(defaults={:default => 1}, "filter", "filter")
        parser.stubs(:add_required_options)
        parser.stubs(:add_common_options)
        parser.expects(:add_filter_options).never
        parser.parse
      end

      it "should parse MCOLLECTIVE_EXTRA_OPTS" do
        ENV["MCOLLECTIVE_EXTRA_OPTS"] = "--dt 999"
        @parser = Optionparser.new
        expect(@parser.parse[:disctimeout]).to eq(999)
        ENV.delete("MCOLLECTIVE_EXTRA_OPTS")
      end

      it "should not set the active collective from the config class if given on the cli" do
        parser = Optionparser.new(defaults={:collective => "rspec"})
        parser.stubs(:add_required_options)
        parser.stubs(:add_common_options)
        Config.instance.expects(:main_collective).never
        parser.parse
      end

      it "should set the active collective from the config class if not given on the cli" do
        parser = Optionparser.new(defaults={})
        parser.stubs(:add_required_options)
        parser.stubs(:add_common_options)
        Config.instance.expects(:main_collective).returns(:rspec).once
        expect(parser.parse[:collective]).to eq(:rspec)
      end
    end

    describe '#add_common_options' do
      before :each do
        @parser = Optionparser.new
      end

      after :each do
        ARGV.pop
      end

      it 'should parse the --target option' do
        ARGV << '--target=rspec_collective'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:collective]).to eq('rspec_collective')
      end

      it 'should parse the --discovery-timeout option' do
        ARGV << '--discovery-timeout=1'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:disctimeout]).to eq(1)
      end

      it 'should parse the --timeout option' do
        ARGV << '--timeout=5'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:timeout]).to eq(5)
      end

      it 'should parse the --quiet option' do
        ARGV << '--quiet'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:verbose]).to eq(false)
      end

      it 'should parse the --ttl option' do
        ARGV << '--ttl=9'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:ttl]).to eq(9)
      end

      it 'should parse the --reply-to option' do
        ARGV << '--reply-to=/rspec/test'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:reply_to]).to eq('/rspec/test')
      end

      it 'should parse the --disc-method option' do
        ARGV << '--disc-method=flatfile'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:discovery_method]).to eq('flatfile')
      end

      it 'should fail on the --disc-method option if the discovery method has already been set' do
        @parser.instance_variable_get(:@options)[:discovery_method] = 'flatfile'
        ARGV << '--disc-method=dm'
        expect{
          @parser.parse
        }.to raise_error('Discovery method is already set by a competing option')
      end

      it 'should parse the --publish_timeout option' do
        ARGV << '--publish_timeout=5'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:publish_timeout]).to eq(5)
      end

      it 'should parse the --threaded option' do
        ARGV << '--threaded'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:threaded]).to eq(true)
      end

      it 'should parse the --disc-option option' do
        ARGV << '--disc-option=option1'
        ARGV << '--disc-option=option2'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:discovery_options]).to eq(['option1', 'option2'])
        ARGV.pop
      end

      it 'should parse the --nodes option' do
        File.expects(:readable?).with('nodes.txt').returns(true)
        ARGV << '--nodes=nodes.txt'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:discovery_method]).to eq('flatfile')
        expect(@parser.instance_variable_get(:@options)[:discovery_options]).to eq(['file=nodes.txt'])
      end

      it 'should parse the --nodes option' do
        ARGV << '--connection-timeout=1'
        @parser.parse
        expect(@parser.instance_variable_get(:@options)[:connection_timeout]).to eq(1)
      end

      it 'should fail on the --nodes option if discovery_method or discovery_options have already been set' do
      end

      it 'should fail if it cannot read the discovery file' do
        File.expects(:readable?).with('nodes.txt').returns(false)
        ARGV << '--nodes=nodes.txt'
        expect{
          @parser.parse
        }.to raise_error('Cannot read the discovery file nodes.txt')
      end
    end
  end
end
