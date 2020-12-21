#!/usr/bin/env rspec

require 'spec_helper'

module MCollective::Facts
  describe Base do
    before do
      class Testfacts<Base; end

      MCollective::PluginManager.delete("facts_plugin")
      MCollective::PluginManager << {:type => "facts_plugin", :class => "MCollective::Facts::Testfacts"}
    end

    describe "#inherited" do
      it "should add classes to the plugin manager" do
        MCollective::PluginManager.expects("<<").with({:type => "facts_plugin", :class => "MCollective::Facts::Bar"})

        class Bar<Base; end
      end

      it "should be available in the PluginManager" do
        expect(MCollective::PluginManager["facts_plugin"].class).to eq(MCollective::Facts::Testfacts)
      end
    end

    describe "#get_fact" do
      it "should call the fact provider #load_facts_from_source" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar"}).once

        f = Testfacts.new
        f.get_fact("foo")
      end

      it "should honor the cache timeout" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar"}).once

        f = Testfacts.new
        f.get_fact("foo")
        f.get_fact("foo")
      end

      it "should detect empty facts" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({})
        MCollective::Log.expects("error").with("Failed to load facts: RuntimeError: Got empty facts").once

        f = Testfacts.new
        f.get_fact("foo")
      end

      it "should convert non string facts to strings" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({:foo => "bar"})

        f = Testfacts.new
        expect(f.get_fact("foo")).to eq("bar")
      end

      it "should not create duplicate facts while converting to strings" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({:foo => "bar"})

        f = Testfacts.new
        expect(f.get_fact(nil).include?(:foo)).to eq(false)
      end

      it "should update last_facts_load on success" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar"}).once

        f = Testfacts.new
        f.get_fact("foo")

        expect(f.instance_variable_get("@last_facts_load")).not_to eq(0)
      end

      it "should restore last known good facts on failure" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({}).once
        MCollective::Log.expects("error").with("Failed to load facts: RuntimeError: Got empty facts").once

        f = Testfacts.new
        f.instance_variable_set("@last_good_facts", {"foo" => "bar"})

        expect(f.get_fact("foo")).to eq("bar")
      end

      it "should return all facts for nil parameter" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar", "bar" => "baz"})

        f = Testfacts.new
        expect(f.get_fact(nil).keys.size).to eq(2)
      end

      it "should return a specific fact when specified" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar", "bar" => "baz"})

        f = Testfacts.new
        expect(f.get_fact("bar")).to eq("baz")
      end
    end

    describe "#get_facts" do
      it "should load and return all facts" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar", "bar" => "baz"})

        f = Testfacts.new
        expect(f.get_facts).to eq({"foo" => "bar", "bar" => "baz"})
      end
    end

    describe "#has_fact?" do
      it "should correctly report fact presense" do
        Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar"})

        f = Testfacts.new
        expect(f.has_fact?("foo")).to eq(true)
        expect(f.has_fact?("bar")).to eq(false)
      end
    end

    describe '#normalize_facts' do
      it 'should make symbols that are keys be strings' do
        expect(Testfacts.new.send(:normalize_facts, {
          :foo  => "1",
          "bar" => "2",
        })).to eq({
          "foo" => "1",
          "bar" => "2",
        })
      end

      it 'should make values that are not strings be strings' do
        expect(Testfacts.new.send(:normalize_facts, {
          "foo" => 1,
          "bar" => :baz,
        })).to eq({
          "foo" => "1",
          "bar" => "baz",
        })
      end

      it 'should not flatten arrays or hashes' do
        expect(Testfacts.new.send(:normalize_facts, {
          "foo" => [ "1", "quux", 2 ],
          "bar" => {
            :baz => "quux",
          },
        })).to eq({
          "foo" => [ "1", "quux", "2" ],
          "bar" => {
            "baz" => "quux",
          },
        })
      end
    end
  end
end
