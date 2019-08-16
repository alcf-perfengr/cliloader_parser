module CLILoader

  module CL

    class Obj
      attr_reader :clid
      attr_reader :creation_date
      attr_accessor :deletion_date
      attr_reader :infos
      attr_reader :state

      def initialize(clid, creation_date, **infos)
        @clid = clid
        @creation_date = creation_date
        @deletion_date = nil
        @infos = infos
        @state = {reference_count: 1}
      end

      def reference_count
        @state[:reference_count]
      end

      def reference_count=(v)
        @state[:reference_count] = v
      end

    end

    module ParsableEvent
      attr_reader :call_params
      attr_reader :returns
      attr_reader :returned
      attr_reader :callbacks

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
          CLILoader::Parser.objects[returned].push o
          @returned = o
        end
        if self.class.callbacks
          self.class.callbacks.each { |c| c.call(self) }
        end
      end

      def self.register_callback(callback)
        unregister_callback(callback)
        @callbacks.push callback if callback
      end

      def self.unregister_callback(callback)
        @callbacks.delete(callback) if callback
      end

      def self.inherited(subclass)
        subclass.extend(ParsableEvent)
        CLILoader::Parser.register(subclass)
      end

      def self.create(sym, call_params: {}, returns: {}, returned: false, callback: nil)
        CLILoader::CL::const_set(sym, Class::new(Evt) do
          @call_params = call_params
          @returns = returns
          @returned = returned
          @callbacks = []
          @callbacks.push callback if callback
        end)
      end

    end

    module Releaser

      def release
        obj = infos[self.class.call_params.keys.first]
        obj.reference_count -= 1
        obj.deletion_date = date if obj.reference_count == 0
      end

      def self.included(klass)
        klass.instance_variable_set(:@callbacks, [lambda { |event| event.release }])
      end

      def self.create(sym, call_params)
        Evt::create(sym, call_params: call_params)
        CLILoader::CL::const_get(sym).include(Releaser)
      end

    end

    module Retainer

      def retain
        obj = infos[self.class.call_params.keys.first]
        obj.reference_count += 1
      end

      def self.included(klass)
        klass.instance_variable_set(:@callbacks, [lambda { |event| event.retain }])
      end

      def self.create(sym, call_params)
        Evt::create(sym, call_params: call_params)
        CLILoader::CL::const_get(sym).include(Retainer)
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
      def initialize(*args)
        super
        @state[:source] = nil
        @state[:compile_count] = 0
        @state[:build_options] = nil
      end
    end

    class Kernel < Obj
      def initialize(*args)
        super
        @state[:args] = []
        @state[:arg_files] = []
        @state[:arg_buff_files_in] = []
        @state[:arg_buff_files_out] = []
        @state[:program_compile_number] = nil
      end
    end

    class Mem < Obj
    end

    class Buffer < Mem
    end

    Evt::create :GetPlatformIDs
    Evt::create :GetPlatformInfo, call_params: { platform: NameList, param_name: Flags }
    Evt::create :GetDeviceIDs, call_params: { platform: NameList, device_type: Flags }
    Evt::create :GetDeviceInfo, call_params: { device: NameList, param_name: Flags }
    Evt::create :CreateContext, call_params: { properties: NameList, num_devices: Integer, devices: NameList }, returned: Context
    Evt::create :GetContextInfo, call_params: { context: Context, param_name: Flags }
    Evt::create :CreateCommandQueue, call_params: { context: Context, device: NameList, properties: Flags }, returned: CommandQueue
    Evt::create :CreateProgramWithSource, call_params: { context: Context, count: Integer }, returns: { :"program number" => String }, returned: Program
    Evt::create :BuildProgram, call_params: { program: Program, pfn_notify: Pointer }
    Evt::create :CreateKernel, call_params: { program: Program, kernel_name: String }, returned: Kernel
    Evt::create :CreateBuffer, call_params: { context: Context, flags: Flags, size: Integer, host_ptr: Pointer }, returned: Buffer
    Evt::create :EnqueueWriteBuffer, call_params: { queue: CommandQueue, buffer: Buffer, blocking: Bool, offset: Integer, cb: Integer, ptr: Pointer }
    Evt::create :EnqueueReadBuffer, call_params: { queue: CommandQueue, buffer: Buffer, blocking: Bool, offset: Integer, cb: Integer, ptr: Pointer }
    Evt::create :SetKernelArg, call_params: { kernel: Kernel, index: Integer, size: Integer, value: Handle }
    Evt::create :EnqueueNDRangeKernel, call_params: { queue: CommandQueue, kernel: Kernel, global_work_offset: Vector, global_work_size: Vector, local_work_size: Vector }
    Evt::create :Finish, call_params: { queue: CommandQueue }

    Releaser::create(:ReleaseMemObject, { mem: Mem })
    Retainer::create(:RetainMemObject, { mem: Mem })

    Releaser::create(:ReleaseProgram, { program: Program })
    Retainer::create(:RetainProgram, { program: Program })

    Releaser::create(:ReleaseKernel, { kernel: Kernel })
    Retainer::create(:RetainKernel, { kernel: Kernel })

    Releaser::create(:ReleaseCommandQueue, { command_queue: CommandQueue })
    Retainer::create(:RetainCommandQueue, { command_queue: CommandQueue })

    Releaser::create(:ReleaseContext, { context: Context })
    Retainer::create(:RetainContext, { context: Context })

  end

end
