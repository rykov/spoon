require 'ffi'

module Spoon
  extend FFI::Library
  ffi_lib 'c'

  # int
  # posix_spawn(pid_t *restrict pid, const char *restrict path,
  #     const posix_spawn_file_actions_t *file_actions,
  #     const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
  #     char *const envp[restrict]);

  attach_function :_posix_spawn, :posix_spawn, [:pointer, :string, :pointer, :pointer, :pointer, :pointer], :int
  attach_function :_posix_spawnp, :posix_spawnp, [:pointer, :string, :pointer, :pointer, :pointer, :pointer], :int

  # File actions
  attach_function :_posix_spawn_file_actions_init,    :posix_spawn_file_actions_init,     [:pointer], :int
  attach_function :_posix_spawn_file_actions_destroy, :posix_spawn_file_actions_destroy,  [:pointer], :int
  attach_function :_posix_spawn_file_actions_adddup2, :posix_spawn_file_actions_adddup2,  [:pointer, :int, :int], :int
  attach_function :_posix_spawn_file_actions_addclose,:posix_spawn_file_actions_addclose, [:pointer, :int], :int

  def self.spawn(*args)
    _with_prepared_spawn_args(args) do |spawn_args|
      _posix_spawn(*spawn_args)
      spawn_args[0].read_int
    end
  end

  def self.spawnp(*args)
    _with_prepared_spawn_args(args) do |spawn_args|
      _posix_spawnp(*spawn_args)
      spawn_args[0].read_int
    end
  end

  private

  def self._with_prepared_spawn_args(args)
    # Make the arguments more like Kernel#spawn in Ruby 1.9
    env = args.first.is_a?(Hash) ? ENV.merge(args.shift) : ENV
    options = args.last.is_a?(Hash) ? args.pop : {}

    pid_ptr = FFI::MemoryPointer.new(:pid_t, 1)

    args_ary = FFI::MemoryPointer.new(:pointer, args.length + 1)
    str_ptrs = args.map {|str| FFI::MemoryPointer.from_string(str)}
    args_ary.put_array_of_pointer(0, str_ptrs)

    env_ary = FFI::MemoryPointer.new(:pointer, env.length + 1)
    env_ptrs = env.map {|key,value| FFI::MemoryPointer.from_string("#{key}=#{value}")}
    env_ary.put_array_of_pointer(0, env_ptrs)

    _with_file_actions(options) do |actions_ptr|
      yield [pid_ptr, args[0], actions_ptr, nil, args_ary, env_ary]
    end
  end

  def self._with_file_actions(options)
    # Initialize
    actions_ptr = FFI::MemoryPointer.new(:pointer, 1) # FIXME
    _posix_spawn_file_actions_init(actions_ptr)

    # Connect the IO redirection
    close_filenos = []
    options.each do |src, dst|
      src_no, dst_no = _fileno_for(src), _fileno_for(dst)

      if src_no && dst_no
        _posix_spawn_file_actions_adddup2(actions_ptr, dst_no, src_no)
        close_filenos << src_no if src_no > 2
        close_filenos << dst_no if dst_no > 2
      end
    end

    # Close all non-standard descriptors (ala Kernel#spawn)
    close_filenos.uniq.each do |fileno|
      _posix_spawn_file_actions_addclose(actions_ptr, fileno)
    end

    # Call the action
    out = yield(actions_ptr)

    # Cleanup
    _posix_spawn_file_actions_destroy(actions_ptr)

    return out
  end

  def self._fileno_for(input)
    if input.is_a?(Fixnum)
      input
    elsif input.respond_to?(:fileno)
      input.fileno
    elsif [:in, :out, :err].include?(input)
      Kernel.const_get("STD#{input.to_s.upcase}").fileno
    end
  end
end

if __FILE__ == $0
  pid = Spoon.spawn('/usr/bin/vim')

  Process.waitpid(pid)
end
