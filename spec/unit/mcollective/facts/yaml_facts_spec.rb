#!/usr/bin/env rspec

require 'spec_helper'
require 'mcollective/facts/yaml_facts'

module MCollective
  module Facts
    describe Yaml_facts do
      before :each do
        config = mock
        config.stubs(:pluginconf).returns({'yaml' => 'facts.yaml'})
        Config.stubs(:instance).returns(config)
        @stat = mock
        File.stubs(:stat).returns(@stat)
        @facts = Yaml_facts.new
      end

      describe '#initialize' do
        it 'should initialize a mtimes instance variable' do
          facts = Yaml_facts.new
          expect(facts.instance_variable_get(:@yaml_file_mtimes)).to eq({})
        end
      end

      describe '#load_facts_from_source' do
        it 'should fail and return empty facts if the source file does not exist' do
          File.stubs(:exist?).with('facts.yaml').returns(false)
          Log.expects(:error)
          expect(@facts.load_facts_from_source).to eq({})
        end

        it 'should fail and return empty facts in the yaml cannot be parsed' do
          yaml = "---"
          YAML.stubs(:load).raises("error")
          File.stubs(:exist?).with('facts.yaml').returns(true)
          File.stubs(:read).with('facts.yaml').returns(yaml)
          Log.expects(:error)
          expect(@facts.load_facts_from_source).to eq({})
        end

        it 'should return the facts if the file exists and can be parsed' do
          yaml = "---\n  osfamily : Magic"
          File.stubs(:exist?).with('facts.yaml').returns(true)
          File.stubs(:read).with('facts.yaml').returns(yaml)
          Log.expects(:error).never
          expect(@facts.load_facts_from_source).to eq({"osfamily" => "Magic"})
        end
      end

      describe '#force_reload?' do
        it 'should return true if the mtime has changed' do
          @facts.instance_variable_get(:@yaml_file_mtimes)['facts.yaml'] = 1234
          @stat.stubs(:mtime).returns(1235)
          expect(@facts.force_reload?).to be_truthy
        end

        it 'should return false if the mtime is the same' do
          @facts.instance_variable_get(:@yaml_file_mtimes)['facts.yaml'] = 1234
          @stat.stubs(:mtime).returns(1234)
          expect(@facts.force_reload?).to be_falsey
        end
      end
    end
  end
end
