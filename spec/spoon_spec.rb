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

  context 'with file actions' do
    it 'should be able to read and write files' do
      path = File.join(File.dirname(__FILE__), 'test.txt')
      path_out = 'out.txt'

      begin
        src = File.new(path)
        dst = File.new(path_out, 'w')
        pid = Spoon.spawnp('cat', { :in => src, :out => dst })
        Process.wait(pid)
        src.close
        dst.close
        IO.read(path_out).should == IO.read(path)
      ensure
        File.unlink(path_out) if File.exist?(path_out)
      end
    end

    it 'should be able to read and write IO.pipe' do
      # FIXME: Need to figure out how to read from a IO.pipe
      path = File.join(File.dirname(__FILE__), 'test.txt')
      src = File.new(path)
      dr, dw = IO.pipe
      pid = Spoon.spawnp('cat', { :in => src, :out => dw })
      Process.wait(pid)
      src.close
      dw.close
      dr.read.should == IO.read(path)
      dr.close
    end

    it 'should work with FD, IO, or symbols' do
      [1, STDOUT, :out].each do |src|
        r, w = IO.pipe
        pid = Spoon.spawnp('echo', 'Hello', { src => w })
        Process.wait(pid)
        w.close
        r.read.should == "Hello\n"
        r.close
      end
    end
  end

  describe '_fileno_for' do
    it 'should understand numbers' do
      Spoon.send(:_fileno_for, 10).should == 10
    end

    it 'should understand file handles' do
      Spoon.send(:_fileno_for, STDERR).should == STDERR.fileno
    end

    it 'should understand symbols' do
      Spoon.send(:_fileno_for, :in) == STDIN.fileno
      Spoon.send(:_fileno_for, :out) == STDOUT.fileno
      Spoon.send(:_fileno_for, :err) == STDERR.fileno
    end
  end
end