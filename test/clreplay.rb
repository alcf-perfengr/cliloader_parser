require 'opencl_ruby_ffi'
require 'narray_ffi'

$device = OpenCL::platforms.first.devices.first

$context = OpenCL::create_context($device)
$queue = $context.create_command_queue($device, properties: [OpenCL::CommandQueue::PROFILING_ENABLE])

TYPE_MAP = {
  char: :Char,
  uchar: :UChar,
  short: :Short,
  ushort: :UShort,
  int: :Int,
  uint: :UInt,
  long: :Long,
  ulong: :ULong,
  float: :Float,
  double: :Double,
  half: :Half
}

NARRAY_TYPE_MAP = {
  char: NArray::BYTE,
  uchar: NArray::BYTE,
  short: NArray::SINT,
  ushort: NArray::SINT,
  int: NArray::INT,
  uint: NArray::INT,
  float: NArray::SFLOAT,
  double: NArray::FLOAT,
}

def create_buffer_argument(kernel_dir, arg, dir: :in)
  arg.type_name =~ /(\w+)(\d*)/
  type = $1.to_sym
  count = $2.to_i

  data = File::read(File::join(kernel_dir, "%02d.buffer.#{dir}" % arg.index), mode: "rb")
  if NARRAY_TYPE_MAP[type]
    n_a = NArray::to_na(data, NARRAY_TYPE_MAP[type])
    return n_a if dir == :out
  else
    return data if dir == :out
  end
  buffer = $context.create_buffer(data.size, host_ptr: data, flags: OpenCL::Mem::COPY_HOST_PTR)
  if NARRAY_TYPE_MAP[type]
    [buffer, n_a]
  else
    [buffer, data]
  end
end

def create_scalar_argument(kernel_dir, arg)
  arg.type_name =~ /(\w+)(\d*)/
  data = File::read(File::join(kernel_dir, "%02d.in" % arg.index), mode: "rb")
  type = $1.to_sym
  count = $2.to_i
  count = 1 if count == 0
  cl_type = OpenCL::const_get(:"#{TYPE_MAP[type]}#{count}")
  cl_type::new(FFI::MemoryPointer.from_string(data))
end

def create_local_argument(kernel_dir, arg)
  data = File::read(File::join(kernel_dir, "%02d.in" % arg.index), mode: "rb")
  data.unpack("J").first
end

def create_argument(kernel_dir, arg, dir: :in)
  case arg.address_qualifier
  when OpenCL::Kernel::Arg::AddressQualifier::GLOBAL
    create_buffer_argument(kernel_dir, arg, dir: dir)
  when OpenCL::Kernel::Arg::AddressQualifier::LOCAL
    create_local_argument(kernel_dir, arg)
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
    program_dir.lazy.reject { |e| e == ".." || e == "." }.select { |entry| Dir.exist?(File::join(program_dir.path,entry)) }.each { |osubdir|
      option_dir = Dir::open(File::join(program_dir.path, osubdir))
      options = ""
      options << File::read(File::join(option_dir.path, "options.txt")) if File.exist?(File::join(option_dir.path, "options.txt"))
      options << " -cl-kernel-arg-info" unless options.match("-cl-kernel-arg-info")
      program.build(options: options)
      option_dir.lazy.reject { |e| e == ".." || e == "." }.select { |entry| Dir.exist?(File::join(option_dir.path,entry)) }.each { |ssubdir|
        kernel_dir = Dir::open(File::join(option_dir.path, ssubdir))
        kernel = program.create_kernel(ssubdir)
        puts kernel.name + ":"
        arguments = []
        kernel_dir.lazy.reject { |e| e == ".." || e == "." }.each { |sssubdir|
          enqueue_dir = Dir::open(File::join(kernel_dir.path, sssubdir))
          args = kernel.args.collect { |arg|
             create_argument(enqueue_dir, arg)
          }
          args.each_with_index { |a, i|
            print "\t#{kernel.args[i].name}:"
            if a.kind_of?(Array)
              puts " #{a[0].inspect}"
              kernel.set_arg(i, a[0])
            elsif a.kind_of?(Numeric)
              puts " #{a}"
              kernel.set_arg(i, nil, a)
            else
              puts " #{a}"
              kernel.set_arg(i, a)
            end
          }
          global_work_offset, global_work_size, local_work_size = get_work_group_data(enqueue_dir)
          print "\t\tEnqueueNDRange: #{global_work_size} #{local_work_size}#{global_work_offset ? " (#{global_work_offset}" : "" }"
          event = $queue.enqueue_NDrange_kernel(kernel, global_work_size, local_work_size: local_work_size, global_work_offset: global_work_offset)
          $queue.finish
          puts " #{event.command_execution_status}"
          puts "\t\ttiming: #{event.profiling_command_end - event.profiling_command_start} ns"
          out_args = kernel.args.collect { |arg|
            create_argument(enqueue_dir, arg, dir: :out)
          }
          args.zip(out_args).each_with_index { |(input, output), i|
            if input.kind_of?(Array)
              print "\t#{kernel.args[i].name}: "
              p input[0]
              $queue.enqueue_read_buffer(input[0], input[1], blocking: true)
              if input[1].kind_of?(NArray)
                error = (output - input[1]).abs.max
                raise "Computation error!" if input[1].integer? and error != 0
                puts "\t\tMax Error: #{error}."
              else
                puts "\t\tMatch: #{output == input[1]}."
              end
            end
          }
        }
      }
    }
  }
}
