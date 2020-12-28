require 'spec_helper'

require 'mcollective/monkey_patches'

describe OpenSSL::SSL::SSLContext do
  it 'sets parameters on initialization' do
    described_class.any_instance.expects(:set_params).at_least_once
    subject
  end

  it 'disables SSLv2 via the SSLContext#options bitmask' do
    expect(subject.options & OpenSSL::SSL::OP_NO_SSLv2).to eq(OpenSSL::SSL::OP_NO_SSLv2)
  end

  it 'explicitly disable SSLv2 ciphers using the ! prefix so they cannot be re-added' do
    if OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
      cipher_str = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
      expect(cipher_str.split(':')).to include('!SSLv2')
    end
  end

  it 'has no ciphers with version SSLv2 enabled' do
    ciphers = subject.ciphers.select do |name, version, bits, alg_bits|
      /SSLv2/.match(version)
    end
    expect(ciphers).to be_empty
  end

  it 'disables SSLv3 via the SSLContext#options bitmask' do
    expect(subject.options & OpenSSL::SSL::OP_NO_SSLv3).to eq(OpenSSL::SSL::OP_NO_SSLv3)
  end

end
