module CLILoaderParser

  module Parser

    CLASSES = []

    def self.register(klass)
      CLASSES.push klass
    end

  end

  module CL

    class Obj
      attr_reader :clid
      attr_accessor :reference_count
      attr_reader :creation_date
      attr_accessor :deletion_date

      def initialize(clid, creation_date, **infos)
        @clid = clid
        @reference_count = 1
        @creation_date = creation_date
        @deletion_date = nil
        @infos = infos
      end

    end

    class Flags
    end

    class Handle
    end

    class Pointer
    end

    class Vector
    end

    class NameList
    end

    class Bool
    end

    class Context < Obj
    end

    class CommandQueue < Obj
    end

    class Program < Obj
    end

    class Kernel < Obj
    end

    class Mem < Obj
    end

    class Buffer < Mem
    end

    module ParsableEvent
      attr_reader :call_params
      attr_reader :returns
      attr_reader :returned
      attr_reader :callback

      def cl_name
        "cl" << self.name.split("::").last
      end
    end

    class Evt
      attr_reader :date
      attr_reader :return_code
      attr_reader :returned
      attr_reader :infos
      def initialize(date, return_code, returned, **infos)
        @date = date
        @return_code = return_code
        @returned = returned
        @infos = infos
        if returned && return_code == "CL_SUCCESS"
          o = self.class.returned::new(returned, date, **infos)
          CLILoaderParser::Parser::OBJECTS[returned] = o
          @returned = o
        end
        if self.class.callback
          self.class.callback.call(self)
        end
      end

      def self.inherited(subclass)
        subclass.extend(ParsableEvent)
        subclass.instance_variable_set(:@call_params, {})
        subclass.instance_variable_set(:@returns, {})
        subclass.instance_variable_set(:@returned, false)
        subclass.instance_variable_set(:@callback, nil)
        CLILoaderParser::Parser.register(subclass)
      end
    end

    class GetPlatformIDs < Evt
    end

    class GetDeviceIDs < Evt
      @call_params = { platform: NameList, device_type: Flags }
    end

    class GetDeviceInfo < Evt
      @call_params = { device: NameList, param_name: Flags }
    end

    class CreateContext < Evt
      @call_params = { properties: NameList, num_devices: Integer, devices: NameList }
      @returned = Context
    end

    class CreateCommandQueue < Evt
      @call_params = { context: Context, device: NameList, properties: Flags }
      @returned = CommandQueue
    end

    class CreateProgramWithSource < Evt
      @call_params = { context: Context, count: Integer }
      @returns = { :"program number" => String }
      @returned = Program
    end

    class BuildProgram < Evt
      @call_params = { program: Program, pfn_notify: Pointer }
    end

    class CreateKernel < Evt
      @call_params = { program: Program, kernel_name: String }
      @returned = Kernel
    end

    class CreateBuffer < Evt
      @call_params = { context: Context, flags: Flags, size: Integer, host_ptr: Pointer }
      @returned = Buffer
    end

    class EnqueueWriteBuffer < Evt
      @call_params = { queue: CommandQueue, buffer: Buffer, blocking: Bool, offset: Integer, cb: Integer, ptr: Pointer }
    end

    class EnqueueReadBuffer < Evt
      @call_params = { queue: CommandQueue, buffer: Buffer, blocking: Bool, offset: Integer, cb: Integer, ptr: Pointer }
    end

    class SetKernelArg < Evt
      @call_params = { kernel: Kernel, index: Integer, size: Integer, value: Handle }
    end

    class EnqueueNDRangeKernel < Evt
      @call_params = { queue: CommandQueue, kernel: Kernel, global_work_offset: Vector, global_work_size: Vector, local_work_size: Vector }
    end

    class Finish < Evt
      @call_params = { queue: CommandQueue }
    end

    module Releaser

      def release
        obj = infos[self.class.call_params.keys.first]
        obj.reference_count -= 1
        obj.deletion_date = date if obj.reference_count == 0
      end

      def self.included(klass)
        klass.instance_variable_set(:@callback, lambda { |event| event.release })
      end

    end

    module Retainer

      def retain
        obj = infos[self.class.call_params.keys.first]
        obj.reference_count += 1
      end

      def self.included(klass)
        klass.instance_variable_set(:@callback, lambda { |event| event.retain })
      end

    end

    class ReleaseMemObject < Evt
      include Releaser
      @call_params = { mem: Mem }
    end

    class RetainMemObject < Evt
      include Retainer
      @call_params = { mem: Mem }
    end

    class ReleaseProgram < Evt
      include Releaser
      @call_params = { program: Program }
    end

    class RetainProgram < Evt
      include Retainer
      @call_params = { program: Program }
    end

    class ReleaseKernel < Evt
      include Releaser
      @call_params = { kernel: Kernel }
    end

    class ReleaseCommandQueue < Evt
      include Releaser
      @call_params = { command_queue: CommandQueue }
    end

    class ReleaseContext < Evt
      include Releaser
      @call_params = { context: Context }
    end

  end

  module Parser

    OBJECTS = {}
    EVENTS = []

    def self.parser_prog
      return @parser_prog
    end

    def self.generate

      param_parser = lambda { |stream, param, kind|
        if kind < CLILoaderParser::CL::Obj || kind == CLILoaderParser::CL::Handle
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = (0x\\h+)/
        if $&
          handle = $1
          args[:"#{param}"] = handle
          obj = OBJECTS[handle]
          args[:"#{param}"] = OBJECTS[$1] if obj
        end
EOF
        elsif kind == Integer
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = (\\d+)/
        args[:"#{param}"] = $1.to_i if $&
EOF
        elsif kind == String
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = (\\w+)/
        args[:"#{param}"] = $1 if $&
EOF
        elsif kind == CLILoaderParser::CL::Bool
          @parser_prog << <<EOF
          #{stream} =~ /#{param}/
          args[:"#{param}"] = true if $&
EOF
        elsif kind == CLILoaderParser::CL::Flags
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = \\w* \\((\\h+)\\)/
        args[:"#{param}"] = $1.to_i(16) if $&
EOF
        elsif kind == CLILoaderParser::CL::Vector
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = <(.*?)>/
        args[:"#{param}"] = $1.split(" x ").collect(&:strip).collect(&:to_i) if $&
EOF
        elsif kind == CLILoaderParser::CL::NameList
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = (\\[.*?\\])/
        args[:"#{param}"] = $1 if $&
EOF
        elsif kind == CLILoaderParser::CL::Pointer
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = \\(nil\\)/
        if $&
          args[:"#{param}"] = nil
        else
          #{stream} =~ /#{param} = (0x\\h+)/
          args[:"#{param}"] = $1 if $&
        end
EOF
        end
      }
      @parser_prog = <<EOF
    def self.parse_block(call_line, return_line)
      case call_line
EOF
      CLASSES.each { |event|
        call_params = event.call_params
        returns = event.returns
        @parser_prog << <<EOF
      when /#{event.cl_name}/
        call_line =~ /EnqueueCounter: (\\d+)/
        date = $1
        return_line =~ /-> (\\w+)/
        return_code = $1
        returned = nil
        args = {}
EOF
        if event.returned
          @parser_prog << <<EOF
        return_line =~ /returned (0x\\h+)/
        returned = $1 if $&
EOF
        end
        call_params.each { |param, kind| param_parser.call("call_line", param, kind) }
        returns.each { |param, kind| param_parser.call("return_line", param, kind) }
        @parser_prog << <<EOF
        EVENTS.push #{event.name}::new(date, return_code, returned, **args)
EOF
        }
      @parser_prog << <<EOF
      else
        raise "Unrecognized OpenCL event: '\#{call_line}'!"
      end
    end
EOF
      eval(@parser_prog)
    end

    def self.parse_log(logfile)
      logfile.lazy.select { |l|
        l.match(/^<<<</) || l.match(/^>>>>/)
      }.each_slice(2) { |call_line, return_line|
        parse_block(call_line, return_line)
      }
    end

  end

  Parser.generate

end
