#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  describe SSL do
    before do
      @rootdir = File.dirname(__FILE__)
      @ssl = SSL.new("#{@rootdir}/../../fixtures/test-public.pem", "#{@rootdir}/../../fixtures/test-private.pem")
    end

    it "should be able to decode base64 text it encoded" do
      expect(@ssl.base64_decode(@ssl.base64_encode("foo"))).to eq("foo")
    end

    it "should decrypt what it encrypted with RSA" do
      crypted = @ssl.aes_encrypt("foo")
      decrypted = @ssl.aes_decrypt(crypted[:key], crypted[:data])

      expect(decrypted).to eq("foo")
    end

    it "should be able to decrypt using RSA private key what it encrypted with RSA public key" do
      crypted = @ssl.rsa_encrypt_with_public("foo")
      decrypted = @ssl.rsa_decrypt_with_private(crypted)

      expect(decrypted).to eq("foo")
    end

    it "should be able to decrypt using RSA public key what it encrypted with RSA private key" do
      crypted = @ssl.rsa_encrypt_with_private("foo")
      decrypted = @ssl.rsa_decrypt_with_public(crypted)

      expect(decrypted).to eq("foo")
    end

    it "using a helper it should be able to decrypt with private key what it encrypted using the public key" do
      expect(@ssl.decrypt_with_private(@ssl.encrypt_with_public("foo"))).to eq("foo")
      expect(@ssl.decrypt_with_private(@ssl.encrypt_with_public("foo", false), false)).to eq("foo")
    end

    it "using a helper it should be able to decrypt with public key what it encrypted using the private key" do
      expect(@ssl.decrypt_with_public(@ssl.encrypt_with_private("foo"))).to eq("foo")
      expect(@ssl.decrypt_with_public(@ssl.encrypt_with_private("foo", false), false)).to eq("foo")
    end

    describe "#initialize" do
      it "should default to aes-256-cbc" do
        expect(@ssl.ssl_cipher).to eq("aes-256-cbc")
      end

      it "should take the configured value when present" do
        Config.instance.stubs("ssl_cipher").returns("aes-128-cbc")
        @ssl = SSL.new("#{@rootdir}/../../fixtures/test-public.pem", "#{@rootdir}/../../fixtures/test-private.pem")

        expect(@ssl.ssl_cipher).to eq("aes-128-cbc")
      end

      it "should set the supplied ssl cipher" do
        @ssl = SSL.new("#{@rootdir}/../../fixtures/test-public.pem", "#{@rootdir}/../../fixtures/test-private.pem", nil, "aes-128-cbc")
        expect(@ssl.ssl_cipher).to eq("aes-128-cbc")
      end

      it "should prefer the supplied cipher over configured cipher" do
        Config.instance.stubs("aes_key_size").returns("foo-foo-foo")
        @ssl = SSL.new("#{@rootdir}/../../fixtures/test-public.pem", "#{@rootdir}/../../fixtures/test-private.pem", nil, "aes-128-cbc")

        expect(@ssl.ssl_cipher).to eq("aes-128-cbc")
      end

      it "should fail on invalid ciphers" do
        expect {
          @ssl = SSL.new("#{@rootdir}/../../fixtures/test-public.pem", "#{@rootdir}/../../fixtures/test-private.pem", nil, "foo-foo-foo")
        }.to raise_error("The supplied cipher 'foo-foo-foo' is not supported")
      end
    end

    describe "#read_key" do
      it "should fail on non exiting files" do
        expect {
          @ssl.read_key(:public, "/nonexisting")
        }.to raise_error("Could not find key /nonexisting")
      end

      it "should fail on existing, empty files" do
        File.expects(:exist?).with('key').returns(true)
        File.expects(:zero?).with('key').returns(true)
        expect{
          @ssl.read_key(:public, 'key')
        }.to raise_error("public key file 'key' is empty")
      end

      it "should fail on unknown key types" do
        expect {
          @ssl.read_key(:unknown, @ssl.public_key_file)
        }.to raise_error("Can only load :public or :private keys")
      end

      it "should read a public key" do
        @ssl.read_key(:public, "#{@rootdir}/../../fixtures/test-public.pem")
      end

      it "should read the public key from a certificate" do
        expect(@ssl.read_key(:public, "#{@rootdir}/../../fixtures/test-cert.pem").to_s).to match(/.+BEGIN.+PUBLIC KEY.+END.+PUBLIC KEY.+/m)
      end

      it "should return nil if no key was given" do
        expect(@ssl.read_key(:public)).to eq(nil)
      end

      it "should return nil if nil key was given" do
        expect(@ssl.read_key(:public, nil)).to eq(nil)
      end

      it "should clear the OpenSSL error queue on ruby 1.8" do
        Util.expects(:ruby_version).returns("1.8.7")
        OpenSSL.expects(:errors)
        @ssl.read_key(:public, "#{@rootdir}/../../fixtures/test-public.pem")
        @ssl.read_key(:private, "#{@rootdir}/../../fixtures/test-private.pem")
      end

      it "should not clear the OpenSSL error queue on ruby > 1.8" do
        Util.expects(:ruby_version).returns("1.9.3")
        OpenSSL.expects(:errors).never
        @ssl.read_key(:public, "#{@rootdir}/../../fixtures/test-public.pem")
        @ssl.read_key(:private, "#{@rootdir}/../../fixtures/test-private.pem")
      end
    end

    describe "#base64_encode" do
      it "should correctly encode" do
        expect(@ssl.base64_encode("foo")).to eq("Zm9v\n")
        expect(SSL.base64_encode("foo")).to eq("Zm9v\n")
      end
    end

    describe "#base64_decode" do
      it "should correctly decode" do
        expect(@ssl.base64_decode("Zm9v")).to eq("foo")
        expect(SSL.base64_decode("Zm9v")).to eq("foo")
      end

      it 'should raise an error when decoding invalid base64' do
        expect { @ssl.base64_decode('.') }.to raise_error ArgumentError
        expect { SSL.base64_decode('.') }.to raise_error ArgumentError
      end
    end

    describe "#aes_encrypt" do
      it "should create a key and data" do
        crypted = @ssl.aes_encrypt("foo")

        expect(crypted.include?(:key)).to eq(true)
        expect(crypted.include?(:data)).to eq(true)
      end
    end

    describe "#aes_decrypt" do
      it "should decrypt correctly given key and data" do
        key = @ssl.base64_decode("rAaCyW6qB0XqZNa9hji0qHwrI3P47t8diLNXoemW9ss=")
        data = @ssl.base64_decode("mSthvO/wSl0ArNOcgysTVw==")

        expect(@ssl.aes_decrypt(key, data)).to eq("foo")
      end

      it "should decrypt correctly given key, data and cipher" do
        key = @ssl.base64_decode("VEma3a/R7fjw2M4d0NIctA==")
        data = @ssl.base64_decode("FkH6qLvKTn7a+uNPe8ciHA==")

        expect { @ssl.aes_decrypt(key, data) }.to raise_error(ArgumentError)

        # new ssl instance configured for aes-128-cbc, should work
        @ssl = SSL.new("#{@rootdir}/../../fixtures/test-public.pem", "#{@rootdir}/../../fixtures/test-private.pem", nil, "aes-128-cbc")
        expect(@ssl.aes_decrypt(key, data)).to eq("foo")
      end
    end

    describe "#md5" do
      it "should produce correct md5 sums" do
        # echo -n 'hello world'|md5sum
        expect(@ssl.md5("hello world")).to eq("5eb63bbbe01eeed093cb22bb8f5acdc3")
      end
    end
    describe "#sign" do
      it "should sign the message without base64 by default" do
        expect(SSL.md5(@ssl.sign("hello world"))).to eq("8269b23f55945aaa82efbff857c845a6")
      end

      it "should support base64 encoding messages" do
        expect(SSL.md5(@ssl.sign("hello world", true))).to eq("8a4eb3c3d44d22c46dc36a7e441d8db0")
      end
    end

    describe "#verify_signature" do
      it "should correctly verify a message signed using the same keypair" do
        expect(@ssl.verify_signature(@ssl.sign("hello world"), "hello world")).to eq(true)
        expect(@ssl.verify_signature(@ssl.sign("hello world", true), "hello world", true)).to eq(true)
      end

      it "should fail to verify messages not signed by the key" do
        expect(@ssl.verify_signature("evil fake signature", "hello world")).to eq(false)
      end
    end

    describe "#decrypt_with_public" do
      it "should decrypt correctly given key and data in base64 format" do
        crypted = {:key=> "YaRcSDdcKgnRZ4Eu2eirl/+lzDgVkPZ41kXAQQNOi+6AfjdbbOW7Zblibx9r\n3TzZAi0ulA94gqNAXPvPC8LaO8W9TtJwlto/RHwDM7ZdfqEImSYoVACFNq28\n+0MLr3K3hIBsB1pyxgFTQul+MrCq+3Fik7Nj7ZKkJUT2veyqbg8=",
          :data=>"TLVw1EYeOaGDmEC/R2I/cA=="}

        expect(@ssl.decrypt_with_public(crypted)).to eq("foo")
      end
    end

    describe "#decrypt_with_private" do
      it "should decrypt correctly given key and data in base64 format" do
        crypted = {:key=> "kO1kUgJBiEBdoajN4OHp9BOie6dCznf1YKbBnp3LOyBxcDDQtjxEBlPmjQve\npXrQJ5xpLX6oNBxzU18Pf2SKYUZSbzIkDUb97GQY0WoBQsdM2OwPXH+HtF2A\no5N8iIx9srPAEAFa6hZAdqvcmRT/SzhP1kH+Gyy8fyvW8HGBjNY=",
          :data=>"gDTaHCmes/Yua4jtjmgukQ=="}

        expect(@ssl.decrypt_with_private(crypted)).to eq("foo")
      end
    end

    describe "#decrypt_with_private" do
      it "should fail if not given a key" do
        expect {
          @ssl.decrypt_with_private({:iv => "x", :data => "x"})
        }.to raise_error("Crypted data should include a key")
      end

      it "should fail if not given data" do
        expect {
          @ssl.decrypt_with_private({:iv => "x", :key => "x"})
        }.to raise_error("Crypted data should include data")
      end
    end

    describe "#decrypt_with_public" do
      it "should fail if not given a key" do
        expect {
          @ssl.decrypt_with_public({:iv => "x", :data => "x"})
        }.to raise_error("Crypted data should include a key")
      end

      it "should fail if not given data" do
        expect {
          @ssl.decrypt_with_public({:iv => "x", :key => "x"})
        }.to raise_error("Crypted data should include data")
      end
    end

    describe "#uuid" do
      it "should produce repeatable uuids" do
        expect(SSL.uuid("hello world")).to eq(SSL.uuid("hello world"))
      end

      it "should not always produce the same uuid" do
        expect(SSL.uuid).not_to eq(SSL.uuid)
      end
    end
  end
end
