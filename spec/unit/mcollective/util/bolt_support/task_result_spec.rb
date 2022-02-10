require "spec_helper"
require "mcollective/util/bolt_support"
require "puppet"

module MCollective
  module Util
    class BoltSupport
      describe TaskResult do
        let(:good_result) do
          {
            "good.example" => {
              "value" => "stdout",
              "type" => "shell",
              "fail_ok" => false
            }
          }
        end

        let(:good_bolt_result) do
          {
            "good.example" => {
              "value" => {
                "agent" => "bolt_tasks",
                "action" => "run_and_wait",
                "sender" => "desktop-6qqubu4.lan",
                "statuscode" => 0,
                "statusmsg" => "OK",
                "data" => {
                  "task_id" => "10e8921c912d5fe7bb87c6324ec6e9ae",
                  "task" => "chocolatey::status",
                  "callerid" => "choria=romain.mcollective",
                  "exitcode" => 0,
                  "stdout" => "{\"status\":[{\"package\":\"chocolatey\",\"version\":\"0.12.1\"},{\"package\":\"chocolatey-core.extension\",\"version\":\"1.3.5.1\"},{\"package\":\"GoogleChrome\",\"version\":\"98.0.4758.82\"}]}",
                  "stderr" => "",
                  "completed" => true,
                  "runtime" => 1.632686,
                  "start_time" => 1644527275
                },
                "requestid" => "10e8921c912d5fe7bb87c6324ec6e9ae"
              },
              "type" => "mcollective",
              "fail_ok" => false
            }
          }
        end

        let(:error_result) do
          {
            "error.example" => {
              "value" => "stdout",
              "type" => "shell",
              "fail_ok" => false,
              "error" => {
                "msg" => "Command failed with code 1",
                "kind" => "choria.playbook/taskerror",
                "details" => {
                  "command" => "/tmp/x.sh"
                }
              }
            }
          }
        end

        describe ".from_asserted_hash" do
          it "should load the correct data" do
            tr = TaskResult.from_asserted_hash(good_result)
            expect(tr.host).to eq("good.example")
            expect(tr.result).to eq(good_result["good.example"])
          end
        end

        describe "#error" do
          it "should be nil when not an error" do
            expect(TaskResult.from_asserted_hash(good_result).error).to be_nil
          end
        end

        describe "#ok" do
          it "should be true when fail_ok is true" do
            error_result["error.example"]["fail_ok"] = true
            tr = TaskResult.from_asserted_hash(error_result)
            expect(tr).to be_ok
          end

          it "should detect errors" do
            tr = TaskResult.from_asserted_hash(error_result)
            expect(tr).to_not be_ok
          end

          it "should detect non errors" do
            tr = TaskResult.from_asserted_hash(good_result)
            expect(tr).to be_ok
          end
        end

        describe "#[]" do
          it "should access the value data" do
            good_result["good.example"]["value"] = {"test" => "rspec"}
            tr = TaskResult.from_asserted_hash(good_result)
            expect(tr["test"]).to eq("rspec")
          end
        end

        describe "#value" do
          it "should get the correct value" do
            tr = TaskResult.from_asserted_hash(good_result)
            expect(tr.value).to eq("stdout")
          end
        end

        describe "#bolt_task_result" do
          it "should get the correct value" do
            tr = TaskResult.from_asserted_hash(good_bolt_result)
            expect(tr.bolt_task_result).to be_a(Hash)
            expect(tr.bolt_task_result["status"]).to be_an(Array)
            expect(tr.bolt_task_result["status"][1]["version"]).to eq("1.3.5.1")
          end
        end

        describe "#type" do
          it "should get the correct type" do
            tr = TaskResult.from_asserted_hash(error_result)
            expect(tr.type).to eq("shell")
          end
        end
      end
    end
  end
end
