#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  module RPC
    describe ActionRunner do
      before(:each) do
        @req = mock
        @req.stubs(:agent).returns("spectester")
        @req.stubs(:action).returns("tester")

        command = "/bin/echo 1"

        @runner = ActionRunner.new(command, @req, :json)
      end

      describe "#initialize" do
        it "should set command" do
          expect(@runner.command).to eq("/bin/echo 1")
        end

        it "should set agent" do
          expect(@runner.agent).to eq("spectester")
        end

        it "should set action" do
          expect(@runner.action).to eq("tester")
        end

        it "should set format" do
          expect(@runner.format).to eq(:json)
        end

        it "should set request" do
          expect(@runner.request).to eq(@req)
        end

        it "should set stdout" do
          expect(@runner.stdout).to eq("")
        end

        it "should set stderr" do
          expect(@runner.stderr).to eq("")
        end

        it "should set the command via path_to_command" do
          ActionRunner.any_instance.expects(:path_to_command).with("rspec").once
          ActionRunner.new("rspec", @req, :json)
        end
      end

      describe "#shell" do
        it "should create a shell instance with correct settings" do
          s = @runner.shell("test", "infile", "outfile")

          expect(s.command).to eq("test infile outfile")
          expect(s.cwd).to eq(Dir.tmpdir)
          expect(s.stdout).to eq("")
          expect(s.stderr).to eq("")
          expect(s.environment["MCOLLECTIVE_REQUEST_FILE"]).to eq("infile")
          expect(s.environment["MCOLLECTIVE_REPLY_FILE"]).to eq("outfile")
        end
      end

      describe "#load_results" do
        it "should call the correct format loader" do
          req = mock
          req.expects(:agent).returns("spectester")
          req.expects(:action).returns("tester")

          runner = ActionRunner.new("/bin/echo 1", req, :foo)
          runner.expects("load_foo_results").returns({:foo => :bar})
          expect(runner.load_results("/dev/null")).to eq({:foo => :bar})
        end

        it "should set all keys to Symbol" do
          data = {"foo" => "bar", "bar" => "baz"}
          Tempfile.open("mcollective_test", Dir.tmpdir) do |f|
            f.puts data.to_json
            f.close

            results = @runner.load_results(f.path)
            expect(results).to eq({:foo => "bar", :bar => "baz"})
          end
        end
      end

      describe "#load_json_results" do
        it "should load data from a file" do
          Tempfile.open("mcollective_test", Dir.tmpdir) do |f|
            f.puts '{"foo":"bar","bar":"baz"}'
            f.close

            expect(@runner.load_json_results(f.path)).to eq({"foo" => "bar", "bar" => "baz"})
          end

        end

        it "should return empty data on JSON parse error" do
          expect(@runner.load_json_results("/dev/null")).to eq({})
        end

        it "should return empty data for missing files" do
          expect(@runner.load_json_results("/nonexisting")).to eq({})
        end

        it "should load complex data correctly" do
          data = {"foo" => "bar", "bar" => {"one" => "two"}}
          Tempfile.open("mcollective_test", Dir.tmpdir) do |f|
            f.puts data.to_json
            f.close

            expect(@runner.load_json_results(f.path)).to eq(data)
          end
        end

      end

      describe "#saverequest" do
        it "should call the correct format serializer" do
          req = mock
          req.expects(:agent).returns("spectester")
          req.expects(:action).returns("tester")

          runner = ActionRunner.new("/bin/echo 1", req, :foo)

          runner.expects("save_foo_request").with(req).returns('{"foo":"bar"}')

          runner.saverequest(req)
        end

        it "should save to a temp file" do
          @req.expects(:to_json).returns({:foo => "bar"}.to_json)
          fname = @runner.saverequest(@req).path

          expect(JSON.load(File.read(fname))).to eq({"foo" => "bar"})
          expect(File.dirname(fname)).to eq(Dir.tmpdir)
        end
      end

      describe "#save_json_request" do
        it "should return correct json data" do
          @req.expects(:to_json).returns({:foo => "bar"}.to_json)
          expect(@runner.save_json_request(@req)).to eq('{"foo":"bar"}')
        end
      end

      describe "#canrun?" do
        it "should correctly report executables" do
          if Util.windows?
            expect(@runner.canrun?(File.join(ENV['SystemRoot'], "explorer.exe"))).to eq(true)
          else
            true_exe = ENV["PATH"].split(File::PATH_SEPARATOR).map {|f| p = File.join(f, "true") ;p if File.exists?(p)}.compact.first
            expect(@runner.canrun?(true_exe)).to eq(true)
          end
        end

        it "should detect missing files" do
          expect(@runner.canrun?("/nonexisting")).to eq(false)
        end
      end

      describe "#to_s" do
        it "should return correct data" do
          expect(@runner.to_s).to eq("spectester#tester command: /bin/echo 1")
        end
      end

      describe "#tempfile" do
        it "should return a TempFile" do
          expect(@runner.tempfile("foo").class).to eq(Tempfile)
        end

        it "should contain the prefix in its name" do
          expect(@runner.tempfile("foo").path).to match(/foo/)
        end
      end

      describe "#path_to_command" do
        it "should return the command if it starts with separator" do
          command = "#{File::SEPARATOR}rspec"

          runner = ActionRunner.new(command , @req, :json)
          expect(runner.path_to_command(command)).to eq(command)
        end

        it "should find the first match in the libdir" do
          Config.instance.expects(:libdir).returns(["#{File::SEPARATOR}libdir1", "#{File::SEPARATOR}libdir2"])

          action_in_first_dir = File.join(File::SEPARATOR, "libdir1", "agent", "spectester", "action.sh")
          action_in_first_dir_new = File.join(File::SEPARATOR, "libdir1", "mcollective", "agent", "spectester", "action.sh")
          action_in_last_dir = File.join(File::SEPARATOR, "libdir2", "agent", "spectester", "action.sh")
          action_in_last_dir_new = File.join(File::SEPARATOR, "libdir2", "mcollective", "agent", "spectester", "action.sh")

          File.expects(:exist?).with(action_in_first_dir).returns(true)
          File.expects(:exist?).with(action_in_first_dir_new).returns(false)
          File.expects(:exist?).with(action_in_last_dir).never
          File.expects(:exist?).with(action_in_last_dir_new).never
          expect(ActionRunner.new("action.sh", @req, :json).command).to eq(action_in_first_dir)
        end

        it "should find the match in the last libdir" do
          Config.instance.expects(:libdir).returns(["#{File::SEPARATOR}libdir1", "#{File::SEPARATOR}libdir2"])

          action_in_first_dir = File.join(File::SEPARATOR, "libdir1", "agent", "spectester", "action.sh")
          action_in_first_dir_new = File.join(File::SEPARATOR, "libdir1", "mcollective", "agent", "spectester", "action.sh")
          action_in_last_dir = File.join(File::SEPARATOR, "libdir2", "agent", "spectester", "action.sh")
          action_in_last_dir_new = File.join(File::SEPARATOR, "libdir2", "mcollective", "agent", "spectester", "action.sh")

          File.expects(:exist?).with(action_in_first_dir).returns(false)
          File.expects(:exist?).with(action_in_first_dir_new).returns(false)
          File.expects(:exist?).with(action_in_last_dir).returns(true)
          File.expects(:exist?).with(action_in_last_dir_new).returns(false)
          expect(ActionRunner.new("action.sh", @req, :json).command).to eq(action_in_last_dir)
        end

        it "should find the match in the 'new' directory layout" do
          Config.instance.expects(:libdir).returns(["#{File::SEPARATOR}libdir1", "#{File::SEPARATOR}libdir2"])

          action_in_new_dir = File.join(File::SEPARATOR, "libdir1", "mcollective", "agent", "spectester", "action.sh")
          action_in_old_dir = File.join(File::SEPARATOR, "libdir1", "agent", "spectester", "action.sh")

          File.expects(:exist?).with(action_in_new_dir).returns(true)
          File.expects(:exist?).with(action_in_old_dir).returns(false)
          expect(ActionRunner.new("action.sh", @req, :json).command).to eq(action_in_new_dir)
        end

        it "if the script is both the old and new locations, the new location should be preferred" do
          Config.instance.expects(:libdir).returns(["#{File::SEPARATOR}libdir1", "#{File::SEPARATOR}libdir2"])

          action_in_new_dir = File.join(File::SEPARATOR, "libdir1", "mcollective", "agent", "spectester", "action.sh")
          action_in_old_dir = File.join(File::SEPARATOR, "libdir1", "agent", "spectester", "action.sh")

          File.expects(:exist?).with(action_in_new_dir).returns(true)
          File.expects(:exist?).with(action_in_old_dir).returns(true)

          expect(ActionRunner.new("action.sh", @req, :json).command).to eq(action_in_new_dir)
        end
      end
    end
  end
end
