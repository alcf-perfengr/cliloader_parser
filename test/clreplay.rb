require 'opencl_ruby_ffi'
require 'narray_ffi'

$device = OpenCL::platforms.first.devices.first

$context = OpenCL::create_context($device)
$queue = $context.create_command_queue($device, properties: [OpenCL::CommandQueue::PROFILING_ENABLE])

def create_buffer_argument(kernel_dir, arg)
  data = File::read(File::join(kernel_dir, "%02d.buffer.in" % arg.index), mode: "rb")
  buffer = $context.create_buffer(data.size, host_ptr: data, flags: OpenCL::Mem::COPY_HOST_PTR)
end

def create_scalar_argument(kernel_dir, arg)
  arg.type_name =~ /(\w+)(\d*)/
  data = File::read(File::join(kernel_dir, "%02d.in" % arg.index), mode: "rb")
  type = $1.to_sym
  count = $2.to_i
  count = 1 if count == 0
  case type
  when :char
  when :uchar
  when :short
  when :ushort
  when :int
    cl_type = OpenCL::const_get(:"Int#{count}")
    cl_type::new(*data.unpack("l#{count}"))
  when :uint
  when :long
  when :ulong
  when :float
    cl_type = OpenCL::const_get(:"Float#{count}")
    cl_type::new(*data.unpack("f#{count}"))
  when :double
  when :half
  end
end

def create_argument(kernel_dir, arg)
  case arg.address_qualifier
  when OpenCL::Kernel::Arg::AddressQualifier::GLOBAL
    create_buffer_argument(kernel_dir, arg)
  #when OpenCL::Kernel::Arg::AddressQualifier::LOCAL
  #when OpenCL::Kernel::Arg::AddressQualifier::CONSTANT
  when OpenCL::Kernel::Arg::AddressQualifier::PRIVATE
    create_scalar_argument(kernel_dir, arg)
  else
    raise "Unsupported argument type!"
  end
end

def get_work_group_data(kernel_dir)
  global_work_offset = nil
  global_work_size = nil
  local_work_size = nil
  File::open(File::join(kernel_dir.path, "global_work_size"), "rb") { |f|
    global_work_size = f.read.unpack("Q*")
  }
  global_work_offset_path = File::join(kernel_dir.path, "global_work_offset")
  if File::exist?(global_work_offset_path)
    File::open(global_work_offset_path, "rb") { |f|
      global_work_offset = f.read.unpack("Q*")
    }
  end
  local_work_size_path = File::join(kernel_dir.path, "local_work_size")
  if File::exist?(local_work_size_path)
    File::open(local_work_size_path, "rb") { |f|
      local_work_size = f.read.unpack("Q*")
    }
  end
  return global_work_offset, global_work_size, local_work_size
end

Dir::open(ARGV[0]) { |d|
  d.lazy.reject { |e| e == ".." || e == "." }.each { |subdir|
    program_dir = Dir::open(File::join(d.path, subdir))
    program = $context.create_program_with_source(File::read(File::join(program_dir.path, "source.cl")))
    program.build(options: "-cl-kernel-arg-info")
    program_dir.lazy.reject { |e| e == ".." || e == "." }.select { |entry| Dir.exist?(File::join(program_dir.path,entry)) }.each { |ssubdir|
      kernel_dir = Dir::open(File::join(program_dir.path, ssubdir))
      kernel = program.create_kernel(ssubdir)
      p kernel
      arguments = []
      kernel_dir.lazy.reject { |e| e == ".." || e == "." }.each { |sssubdir|
        enqueue_dir = Dir::open(File::join(kernel_dir.path, sssubdir))
        args = kernel.args.collect { |arg|
           create_argument(enqueue_dir, arg)
        }
        args.each_with_index { |a, i|
          p a
          kernel.set_arg(i, a)
        }
        global_work_offset, global_work_size, local_work_size = get_work_group_data(enqueue_dir)
        puts "#{global_work_size} #{local_work_size} (#{global_work_offset})"
        event = $queue.enqueue_NDrange_kernel(kernel, global_work_size, local_work_size: local_work_size, global_work_offset: global_work_offset)
        $queue.finish
        p event
        p "#{event.profiling_command_end - event.profiling_command_start} ns"
      }
    }
  }
}
