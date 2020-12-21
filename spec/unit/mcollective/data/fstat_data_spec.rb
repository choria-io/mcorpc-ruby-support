#!/usr/bin/env rspec

require 'spec_helper'

require 'mcollective/data/fstat_data'

module MCollective
  module Data
    describe Fstat_data do
      describe "#query_data" do
        before do
          @ddl = mock
          @ddl.stubs(:meta).returns({:timeout => 1})
          @ddl.stubs(:dataquery_interface).returns({:output => {}})
          DDL.stubs(:new).returns(@ddl)
          @plugin = Fstat_data.new

          @time = Time.now

          @stat = mock
          @stat.stubs(:size).returns(123)
          @stat.stubs(:uid).returns(0)
          @stat.stubs(:gid).returns(0)
          @stat.stubs(:mtime).returns(@time)
          @stat.stubs(:ctime).returns(@time)
          @stat.stubs(:atime).returns(@time)
          @stat.stubs(:mode).returns(33188)
          @stat.stubs(:directory?).returns(false)
          @stat.stubs(:file?).returns(false)
          @stat.stubs(:symlink?).returns(false)
          @stat.stubs(:socket?).returns(false)
          @stat.stubs(:chardev?).returns(false)
          @stat.stubs(:blockdev?).returns(false)
        end

        it "should detect missing files" do
          File.expects(:exist?).with("/nonexisting").returns(false)
          @plugin.query_data("/nonexisting")
          expect(@plugin.result.output).to eq("not present")
        end

        it "should provide correct file stats" do
          File.expects(:exist?).with("rspec").returns(true)
          File.expects(:symlink?).with("rspec").returns(false)
          File.expects(:stat).with("rspec").returns(@stat)
          File.expects(:read).with("rspec").returns("rspec")

          @stat.stubs(:file?).returns(true)

          @plugin.query_data("rspec")
          expect(@plugin.result.output).to eq("present")
          expect(@plugin.result.size).to eq(123)
          expect(@plugin.result.uid).to eq(0)
          expect(@plugin.result.gid).to eq(0)
          expect(@plugin.result.mtime).to eq(@time.strftime("%F %T"))
          expect(@plugin.result.mtime_seconds).to eq(@time.to_i)
          expect(@plugin.result.mtime_age).to be <= 5
          expect(@plugin.result.ctime).to eq(@time.strftime("%F %T"))
          expect(@plugin.result.ctime_seconds).to eq(@time.to_i)
          expect(@plugin.result.ctime_age).to be <= 5
          expect(@plugin.result.atime).to eq(@time.strftime("%F %T"))
          expect(@plugin.result.atime_seconds).to eq(@time.to_i)
          expect(@plugin.result.atime_age).to be <= 5
          expect(@plugin.result.mode).to eq("100644")
          expect(@plugin.result.md5).to eq("2bc84dc69b73db9383b9c6711d2011b7")
          expect(@plugin.result.type).to eq("file")
        end

        it "should provide correct link stats" do
          File.expects(:exist?).with("rspec").returns(true)
          File.expects(:symlink?).with("rspec").returns(true)
          File.expects(:lstat).with("rspec").returns(@stat)

          @stat.stubs(:symlink?).returns(true)

          @plugin.query_data("rspec")
          expect(@plugin.result.output).to eq("present")
          expect(@plugin.result.md5).to eq(0)
          expect(@plugin.result.type).to eq("symlink")
        end

        it "should provide correct directory stats" do
          File.expects(:exist?).with("rspec").returns(true)
          File.expects(:symlink?).with("rspec").returns(false)
          File.expects(:stat).with("rspec").returns(@stat)

          @stat.stubs(:directory?).returns(true)

          @plugin.query_data("rspec")
          expect(@plugin.result.output).to eq("present")
          expect(@plugin.result.md5).to eq(0)
          expect(@plugin.result.type).to eq("directory")
        end

        it "should provide correct socket stats" do
          File.expects(:exist?).with("rspec").returns(true)
          File.expects(:symlink?).with("rspec").returns(false)
          File.expects(:stat).with("rspec").returns(@stat)

          @stat.stubs(:socket?).returns(true)

          @plugin.query_data("rspec")
          expect(@plugin.result.output).to eq("present")
          expect(@plugin.result.md5).to eq(0)
          expect(@plugin.result.type).to eq("socket")
        end

        it "should provide correct chardev stats" do
          File.expects(:exist?).with("rspec").returns(true)
          File.expects(:symlink?).with("rspec").returns(false)
          File.expects(:stat).with("rspec").returns(@stat)

          @stat.stubs(:chardev?).returns(true)

          @plugin.query_data("rspec")
          expect(@plugin.result.output).to eq("present")
          expect(@plugin.result.md5).to eq(0)
          expect(@plugin.result.type).to eq("chardev")
        end

        it "should provide correct blockdev stats" do
          File.expects(:exist?).with("rspec").returns(true)
          File.expects(:symlink?).with("rspec").returns(false)
          File.expects(:stat).with("rspec").returns(@stat)

          @stat.stubs(:blockdev?).returns(true)

          @plugin.query_data("rspec")
          expect(@plugin.result.output).to eq("present")
          expect(@plugin.result.md5).to eq(0)
          expect(@plugin.result.type).to eq("blockdev")
        end
      end
    end
  end
end
