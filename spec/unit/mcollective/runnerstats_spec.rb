#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe RunnerStats do
    before do
      Agents.stubs(:agentlist).returns("agents")
      Time.stubs(:now).returns(Time.at(0))

      @stats = RunnerStats.new

      logger = mock
      logger.stubs(:log)
      logger.stubs(:start)
      Log.configure(logger)
    end

    describe "#to_hash" do
      it "should return the correct data" do
        expect(@stats.to_hash.keys.sort).to eq([:stats, :threads, :pid, :times, :agents].sort)

        expect(@stats.to_hash[:stats]).to eq({:validated => 0, :unvalidated => 0, :passed => 0, :filtered => 0,
          :starttime => 0, :total => 0, :ttlexpired => 0, :replies => 0})

        expect(@stats.to_hash[:agents]).to eq("agents")
      end
    end

    [[:ttlexpired, :ttlexpired], [:passed, :passed], [:filtered, :filtered],
     [:validated, :validated], [:received, :total], [:sent, :replies]].each do |tst|
      describe "##{tst.first}" do
        it "should increment #{tst.first}" do
          @stats.send(tst.first)
          expect(@stats.to_hash[:stats][tst.last]).to eq(1)
        end
      end
    end
  end
end
