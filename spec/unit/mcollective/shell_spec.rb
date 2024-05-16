#!/usr/bin/env rspec

require 'spec_helper'
require 'pathname'

module MCollective
  describe Shell do
    describe "#initialize" do
      it "should set locale by default" do
        s = Shell.new("date")
        expect(s.environment).to eq({"LC_ALL" => "C"})
      end

      it "should merge environment and keep locale" do
        s = Shell.new("date", :environment => {"foo" => "bar"})
        expect(s.environment).to eq({"LC_ALL" => "C", "foo" => "bar"})
      end

      it "should allow locale to be overridden" do
        s = Shell.new("date", :environment => {"LC_ALL" => "TEST", "foo" => "bar"})
        expect(s.environment).to eq({"LC_ALL" => "TEST", "foo" => "bar"})
      end

      it "should allow locale to be cleared" do
        s = Shell.new("date", :environment => {"LC_ALL" => nil, "foo" => "bar"})
        expect(s.environment).to eq({"foo" => "bar"})
      end

      it "should set no environment when given nil" do
        s = Shell.new("date", :environment => nil)
        expect(s.environment).to eq({})
      end

      it "should save the command" do
        s = Shell.new("date")
        expect(s.command).to eq("date")
      end

      it "should check the cwd exist" do
        expect {
          s = Shell.new("date", :cwd => "/nonexistant")
        }.to raise_error("Directory /nonexistant does not exist")
      end

      it "should warn of illegal stdin" do
        expect {
          s = Shell.new("date", :stdin => nil)
        }.to raise_error("stdin should be a String")
      end

      it "should warn of illegal stdout" do
        expect {
          s = Shell.new("date", :stdout => nil)
        }.to raise_error("stdout should support <<")
      end

      it "should warn of illegal stderr" do
        expect {
          s = Shell.new("date", :stderr => nil)
        }.to raise_error("stderr should support <<")
      end

      it "should set stdout" do
        s = Shell.new("date", :stdout => "stdout")
        expect(s.stdout).to eq("stdout")
      end

      it "should set stderr" do
        s = Shell.new("date", :stderr => "stderr")
        expect(s.stderr).to eq("stderr")
      end

      it "should set stdin" do
        s = Shell.new("date", :stdin => "hello world")
        expect(s.stdin).to eq("hello world")
      end
    end

    describe "#runcommand" do
      let(:nl) do
        if MCollective::Util.windows? && STDOUT.tty? && STDERR.tty?
          "\r\n"
        else
          "\n"
        end
      end

      before :each do
        @systemu = mock
        @thread = mock
        @thread.stubs(:kill)
        @systemu.stubs(:thread).returns(@thread)
      end

      it "should run the command" do
        s = Shell.new("date")
        s.stubs("systemu").returns(@systemu).once.with("date", "stdout" => '', "stderr" => '', "env" => {"LC_ALL" => "C"}, 'cwd' => Dir.tmpdir)
        s.runcommand
      end

      it "should set stdin, stdout and status" do
        s = Shell.new('ruby -e "STDERR.puts \"stderr\"; STDOUT.puts \"stdout\""')
        s.runcommand
        expect(s.stdout).to eq("stdout#{nl}")
        expect(s.stderr).to eq("stderr#{nl}")
        expect(s.status.exitstatus).to eq(0)
      end

      it "should report correct exitcode" do
        s = Shell.new('ruby -e "exit 1"')
        s.runcommand

        expect(s.status.exitstatus).to eq(1)
      end

      it "should have correct environment" do
        s = Shell.new('ruby -e "puts ENV[\'LC_ALL\'];puts ENV[\'foo\'];"', :environment => {"foo" => "bar"})
        s.runcommand
        expect(s.stdout).to eq("C#{nl}bar#{nl}")
      end

      it "should save stdout in custom stdout variable" do
        out = "STDOUT"

        s = Shell.new('echo foo', :stdout => out)
        s.runcommand

        expect(s.stdout).to eq("STDOUTfoo#{nl}")
        expect(out).to eq("STDOUTfoo#{nl}")
      end

      it "should save stderr in custom stderr variable" do
        out = "STDERR"

        s = Shell.new('ruby -e "STDERR.puts \"foo\""', :stderr => out)
        s.runcommand

        expect(s.stderr).to eq("STDERRfoo#{nl}")
        expect(out).to eq("STDERRfoo#{nl}")
      end

      it "should run in the correct cwd" do
        tmpdir = Pathname.new(Dir.tmpdir).realpath.to_s
        s = Shell.new('ruby -e "puts Dir.pwd"', :cwd => tmpdir)

        s.runcommand

        expect(s.stdout).to eq("#{tmpdir}#{nl}")
      end

      it "should send the stdin" do
        s = Shell.new('ruby -e "puts STDIN.gets"', :stdin => "hello world")
        s.runcommand

        expect(s.stdout).to eq("hello world#{nl}")
      end

      it "should support multiple lines of stdin" do
        s = Shell.new('ruby -e "puts STDIN.gets;puts;puts STDIN.gets"', :stdin => "first line\n2nd line")
        s.runcommand

        expect(s.stdout).to eq("first line#{nl}#{nl}2nd line#{nl}")
      end

      it "should quietly catch Errno::ESRCH if the systemu process has completed" do
        s = Shell.new("echo foo")
        Thread.current.stubs(:alive?).raises(Errno::ESRCH)
        s.runcommand
      end

      describe "timeout has been set" do
        before do
          thread = mock
          thread.stubs(:alive?).returns(false)
          Thread.stubs(:current).returns(thread)
          Util.stubs(:windows?).returns(false)
          Thread.stubs(:alive?).returns(false)
          Process.expects(:kill).with("TERM", 1234)
          Process.expects(:waitpid).with(1234)
        end

        it "should terminate the systemu process after the specified timeout is exceeded" do
          s = Shell.new(%{ruby -e 'sleep 5'}, :timeout => 1)
          s.stubs(:systemu).yields(1234).returns(@systemu)
          s.stubs(:sleep).with(2)
          s.expects(:sleep).with(1)
          Process.stubs(:kill).with(0, 1234).returns(1, nil)
          s.runcommand
        end

        it "should kill an unresponsive systemu process on timeout" do
          s = Shell.new(%{ruby -e 'sleep 5'}, :timeout => 1)
          s.stubs(:systemu).yields(1234).returns(@systemu)
          s.expects(:sleep).with(1)
          s.stubs(:sleep).with(2)
          Process.stubs(:kill).with(0, 1234).returns(1)
          Process.expects(:kill).with("KILL", 1234)
          s.runcommand
        end

        it "should kill the systemu process if the parent thread exits and :on_thread_exit is specified" do
          s = Shell.new(%{ruby -e 'sleep 5'}, :timeout => :on_thread_exit)
          s.stubs(:systemu).yields(1234).returns(@systemu)
          s.stubs(:sleep).with(2)
          Process.stubs(:kill).with(0, 1234).returns(1)
          Process.expects(:kill).with("KILL", 1234)
          s.runcommand
        end
      end

      it "should log a warning if the child process cannot be reaped" do
        s = Shell.new('ruby -e "sleep 2"', :timeout=> 1)
        Thread.stubs(:current)
        s.stubs(:systemu).yields(1234).returns(@systemu)
        s.stubs(:sleep).with(1).raises(Errno::ECHILD)
        Log.expects(:warn).with("Could not reap process '1234'.")
        s.runcommand
      end
    end
  end
end
