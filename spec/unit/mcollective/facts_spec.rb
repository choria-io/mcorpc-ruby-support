#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe Facts do
    before do
      class Facts::Testfacts<Facts::Base; end

      PluginManager.delete("facts_plugin")
      PluginManager << {:type => "facts_plugin", :class => "MCollective::Facts::Testfacts"}
    end

    describe "#has_fact?" do
      it "should correctly report fact presense" do
        Facts::Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar"})

        expect(Facts.has_fact?("foo", "foo")).to eq(false)
        expect(Facts.has_fact?("foo", "bar")).to eq(true)
      end
    end

    describe "#get_fact" do
      it "should return the correct fact" do
        Facts::Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar"})

        expect(Facts.get_fact("foo")).to eq("bar")
      end
    end

    describe "#[]" do
      it "should return the correct fact" do
        Facts::Testfacts.any_instance.stubs("load_facts_from_source").returns({"foo" => "bar"})

        expect(Facts["foo"]).to eq("bar")
      end
    end
  end
end
