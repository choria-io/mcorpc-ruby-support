#!/usr/bin/env rspec

require 'spec_helper'
require 'mcollective/application/facts'

module MCollective
  class Application
    describe Facts do
      describe "#stringify_facts_hash" do
        it "should convert keys to strings" do
          h = { 2 => ["node1"], true: ["node2", "node3"] }

          expect(subject.stringify_facts_hash(h)).to eq({
            "2" => ["node1"],
            "true" => ["node2", "node3"],
          })
        end

        it "should merge equivalent keys" do
          h = { true => ["node1"], "true": ["node2", "node3"] }

          expect(subject.stringify_facts_hash(h)).to eq({
            "true" => ["node1", "node2", "node3"],
          })
        end
      end
    end
  end
end
