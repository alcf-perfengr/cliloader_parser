require 'opencl_ruby_ffi'
require 'narray_ffi'

$device = OpenCL::platforms.first.devices.first

$context = OpenCL::create_context($device)
$queue = $context.create_command_queue($device)

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
        kernel.args.each { |arg|
          kernel.set_arg(arg.index, create_argument(enqueue_dir, arg))
        }
      }
    }
  }
}
