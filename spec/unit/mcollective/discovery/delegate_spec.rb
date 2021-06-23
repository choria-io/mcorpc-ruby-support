require "spec_helper"

module MCollective
  class Discovery
    describe Delegate do
      describe "#discover" do
        before(:each) do
          @options = {
            config: '/tmp/client.conf',
          }
          @client = mock
          @client.stubs(:options).returns(@options)

          Util.expects(:command_in_path?).with("choria").returns(true)
        end

        it "should execute the correct command" do
          filter = Util.empty_filter
          filter["fact"] << {:fact => "country", :operator => "==", :value => "mt"}
          filter["fact"] << {:fact => "architecture", :operator => "==", :value => "x86_64"}
          filter["cf_class"] << "one" << "/two/"
          filter["identity"] << "node.1" << "/2/"
          filter["agent"] << "rpcutil" << "puppet"
          filter["compound"] << [{"expr" => 'with("country=mt")'}]
          filter["compound"] << [{"expr" => 'with("architecture=x86_64")'}]

          @options[:discovery_method] = "inventory"
          @options[:discovery_options] = ["file=~/inventory.yaml"] << "other=1"

          Delegate.stubs(:binary_name).returns("choria")
          Delegate.expects(:run_discover).with(['choria',
                                                'discover',
                                                '-j',
                                                '--silent',
                                                '--config', '/tmp/client.conf',
                                                '-I', 'node.1',
                                                '-I', '/2/',
                                                '-C', 'one',
                                                '-C', '/two/',
                                                '-F', 'country==mt',
                                                '-F', 'architecture==x86_64',
                                                '-A', 'rpcutil',
                                                '-A', 'puppet',
                                                '-S', 'with("country=mt")',
                                                '-S', 'with("architecture=x86_64")',
                                                '--do', 'file=~/inventory.yaml',
                                                '--do', 'other=1',
                                                '--dm', 'inventory'], 2).returns(["one", "two"])

          expect(Delegate.discover(filter, 2, 0, @client)).to eq(["one", "two"])
        end

        it "should invoke choria" do
          Delegate.stubs(:binary_name).returns("spec/fixtures/discovery/choria.sh")
          filter = Util.empty_filter
          filter["cf_class"] << "one" << "/two/"
          expect(Delegate.discover(filter, 2, 0, @client)).to eq(["node1", "node2"])
        end
      end
    end
  end
end
