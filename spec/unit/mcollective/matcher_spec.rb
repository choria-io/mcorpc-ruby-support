#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe Matcher do
    describe "#create_function_hash" do
      it "should create a correct hash for a 'normal' function call using single quotes" do
        result = Matcher.create_function_hash("foo('bar').res=1")
        expect(result["value"]).to eq("res")
        expect(result["params"]).to eq("bar")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("==")
        expect(result["name"]).to eq("foo")
      end

      it "should create a correct hash for a 'normal' function call using double quotes" do
        result = Matcher.create_function_hash('foo("bar").res=1')
        expect(result["value"]).to eq("res")
        expect(result["params"]).to eq("bar")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("==")
        expect(result["name"]).to eq("foo")
       end

      it "should create a correct hash when a paramater contains a dot value" do
        result = Matcher.create_function_hash("foo('bar.1').res=1")
        expect(result["value"]).to eq("res")
        expect(result["params"]).to eq("bar.1")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("==")
        expect(result["name"]).to eq("foo")
      end

      it "should create a correct hash when right compare value is a regex" do
        result = Matcher.create_function_hash("foo('bar').res=/reg/")
        expect(result["value"]).to eq("res")
        expect(result["params"]).to eq("bar")
        expect(result["r_compare"]).to eq(/reg/)
        expect(result["operator"]).to eq("=~")
        expect(result["name"]).to eq("foo")
      end

      it "should create a correct hash when the operator is >= or <=" do
        result = Matcher.create_function_hash("foo('bar').res<=1")
        expect(result["value"]).to eq("res")
        expect(result["params"]).to eq("bar")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("<=")
        expect(result["name"]).to eq("foo")

        result = Matcher.create_function_hash("foo('bar').res>=1")
        expect(result["value"]).to eq("res")
        expect(result["params"]).to eq("bar")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq(">=")
        expect(result["name"]).to eq("foo")
      end

      it "should create a correct hash when no dot value is present" do
        result = Matcher.create_function_hash("foo('bar')<=1")
        expect(result["value"]).to eq(nil)
        expect(result["params"]).to eq("bar")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("<=")
        expect(result["name"]).to eq("foo")
      end

      it "should create a correct hash when a dot is present in a parameter but no dot value is present" do
        result = Matcher.create_function_hash("foo('bar.one')<=1")
        expect(result["value"]).to eq(nil)
        expect(result["params"]).to eq("bar.one")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("<=")
        expect(result["name"]).to eq("foo")
      end

      it "should create a correct hash when multiple dots are present in parameters but no dot value is present" do
        result = Matcher.create_function_hash("foo('bar.one.two, bar.three.four')<=1")
        expect(result["value"]).to eq(nil)
        expect(result["params"]).to eq("bar.one.two, bar.three.four")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("<=")
        expect(result["name"]).to eq("foo")
      end

      it "should create a correct hash when no parameters are given" do
        result = Matcher.create_function_hash("foo()<=1")
        expect(result["value"]).to eq(nil)
        expect(result["params"]).to eq(nil)
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("<=")
        expect(result["name"]).to eq("foo")
     end

      it "should create a correct hash parameters are empty strings" do
        result = Matcher.create_function_hash("foo('')=1")
        expect(result["value"]).to eq(nil)
        expect(result["params"]).to eq("")
        expect(result["r_compare"]).to eq("1")
        expect(result["operator"]).to eq("==")
        expect(result["name"]).to eq("foo")
      end
    end

    describe "#execute_function" do
      it "should return the result of an evaluated function with a dot value" do
        data = mock
        data.expects(:send).with("value").returns("success")
        MCollective::Data.expects(:send).with("foo", "bar").returns(data)
        result = Matcher.execute_function({"name" => "foo", "params" => "bar", "value" => "value"})
        expect(result).to eq("success")
      end

      it "should return the result of an evaluated function without a dot value" do
        MCollective::Data.expects(:send).with("foo", "bar").returns("success")
        result = Matcher.execute_function({"name" => "foo", "params" => "bar"})
        expect(result).to eq("success")
      end

      it "should return nil if the result cannot be evaluated" do
        data = mock
        data.expects(:send).with("value").raises("error")
        Data.expects(:send).with("foo", "bar").returns(data)
        result = Matcher.execute_function({"name" => "foo", "params" => "bar", "value" => "value"})
        expect(result).to eq(nil)
      end
    end

    describe "#eval_compound_statement" do
      it "should return correctly on a regex class statement" do
        Util.expects(:has_cf_class?).with("/foo/").returns(true)
        expect(Matcher.eval_compound_statement({"statement" => "/foo/"})).to eq(true)
        Util.expects(:has_cf_class?).with("/foo/").returns(false)
        expect(Matcher.eval_compound_statement({"statement" => "/foo/"})).to eq(false)
      end

      it "should return correcly for string and regex facts" do
        Util.expects(:has_fact?).with("foo", "bar", "==").returns(true)
        expect(Matcher.eval_compound_statement({"statement" => "foo=bar"})).to eq("true")
        Util.expects(:has_fact?).with("foo", "/bar/", "=~").returns(false)
        expect(Matcher.eval_compound_statement({"statement" => "foo=/bar/"})).to eq("false")
      end

      it "should return correctly on a string class statement" do
        Util.expects(:has_cf_class?).with("foo").returns(true)
        expect(Matcher.eval_compound_statement({"statement" => "foo"})).to eq(true)
        Util.expects(:has_cf_class?).with("foo").returns(false)
        expect(Matcher.eval_compound_statement({"statement" => "foo"})).to eq(false)
      end
    end

    describe "#eval_compound_fstatement" do
      describe "it should return false if a string, true or false are compared with > or <" do
        let(:function_hash) do
          {"name" => "foo",
           "params" => "bar",
           "value" => "value",
           "operator" => "<",
           "r_compare" => "teststring"}
        end


        it "should return false if a string is compare with a < or >" do
          Matcher.expects(:execute_function).returns("teststring")
          result = Matcher.eval_compound_fstatement(function_hash)
          expect(result).to eq(false)
        end

        it "should return false if a TrueClass is compared with a < or > " do
          Matcher.expects(:execute_function).returns(true)
          result = Matcher.eval_compound_fstatement(function_hash)
          expect(result).to eq(false)
        end

        it "should return false if a FalseClass is compared with a < or >" do
          Matcher.expects(:execute_function).returns(false)
          result = Matcher.eval_compound_fstatement(function_hash)
          expect(result).to eq(false)
        end

        it "should return false immediately if the function execution returns nil" do
          Matcher.expects(:execute_function).returns(nil)
          result = Matcher.eval_compound_fstatement(function_hash)
          expect(result).to eq(false)
        end
      end

      describe "it should return false if backticks are present in parameters and if non strings are compared with regex's" do
        before :each do
          @function_hash = {"name" => "foo",
                           "params" => "bar",
                           "value" => "value",
                           "operator" => "=",
                           "r_compare" => "1"}
        end

        it "should return false if a backtick is present in a parameter" do
          @function_hash["params"] = "`bar`"
          Matcher.expects(:execute_function).returns("teststring")
          MCollective::Log.expects(:debug).with("Cannot use backticks in function parameters")
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(false)
        end

        it "should return false if left compare object isn't a string and right compare is a regex" do
          Matcher.expects(:execute_function).returns(1)
          @function_hash["r_compare"] = "/foo/"
          @function_hash["operator"] = "=~"
          MCollective::Log.expects(:debug).with("Cannot do a regex check on a non string value.")
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(false)
        end
      end

      describe "it should return the expected result for valid function hashes" do
        before :each do
          @function_hash = {"name" => "foo",
                            "params" => "bar",
                            "value" => "value",
                            "operator" => "=",
                            "r_compare" => ""}
        end

        it "should return true if right value is a regex and matches the left value" do
          Matcher.expects(:execute_function).returns("teststring")
          @function_hash["r_compare"] = /teststring/
          @function_hash["operator"] = "=~"
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(true)
        end

        it "should return false if right value is a regex and matches the left value and !=~ is the operator" do
          Matcher.expects(:execute_function).returns("teststring")
          @function_hash["r_compare"] = /teststring/
          @function_hash["operator"] = "!=~"
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(false)
        end

        it "should return false if right value is a regex, operator is != and regex equals left value" do
          Matcher.expects(:execute_function).returns("teststring")
          @function_hash["r_compare"] = /teststring/
          @function_hash["operator"] = "!=~"
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(false)
        end

        it "should return false if right value is a regex and does not match left value" do
          Matcher.expects(:execute_function).returns("testsnotstring")
          @function_hash["r_compare"] = /teststring/
          @function_hash["operator"] = "=~"
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(false)
        end

        it "should return true if left value logically compares to the right value" do
          Matcher.expects(:execute_function).returns(1)
          @function_hash["r_compare"] = 1
          @function_hash["operator"] = ">="
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(true)
       end

        it "should handle integer literals" do
          Matcher.expects(:execute_function).returns(10)
          @function_hash["r_compare"] = "0xa"
          @function_hash["operator"] = "="
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(true)
        end

        it "should handle float literals" do
          Matcher.expects(:execute_function).returns(50)
          @function_hash["r_compare"] = "0.5e2"
          @function_hash["operator"] = "="
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(true)
        end

       it "should return true if we do a false=false comparison" do
          Matcher.expects(:execute_function).returns(false)
          @function_hash["r_compare"] = false
          @function_hash["operator"] = "=="
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(true)
       end

        it "should return false if left value does not logically compare to right value" do
          Matcher.expects(:execute_function).returns("1")
          @function_hash["r_compare"] = "1"
          @function_hash["operator"] = ">"
          result = Matcher.eval_compound_fstatement(@function_hash)
          expect(result).to eq(false)
        end
      end
    end

    describe "#create_compound_callstack" do
      it "should create a callstack from a valid call_string" do
        result = Matcher.create_compound_callstack("foo('bar')=1 and bar=/bar/")
        expect(result).to eq([{"fstatement" => {"params"=>"bar", "name"=>"foo", "operator"=>"==", "r_compare"=>"1"}}, {"and" => "and"}, {"statement" => "bar=/bar/"}])
      end
    end
  end
end
