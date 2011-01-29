$: << File.dirname(__FILE__) + '/../lib'
require 'spoon'

describe Spoon do
  shared_examples_for 'a basic process' do
    it { should be_a_kind_of(Fixnum) }
    it { lambda { Process.waitpid(subject) }.should_not raise_error }
  end

  context 'spawn with a basic process' do
    subject { Spoon.spawn('/bin/sleep', '0.1') }
    it_should_behave_like 'a basic process'
  end

  context 'spawnp with a basic process' do
    subject { Spoon.spawnp('sleep', '0.1') }
    it_should_behave_like 'a basic process'
  end
end