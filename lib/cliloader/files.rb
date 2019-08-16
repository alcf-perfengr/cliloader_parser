module CLILoader

  module Files
    extend Callbacks

    class << self
      attr_accessor :dir
    end

    PROGRAM_SOURCE_REGEX = /CLI_(?<program_number>\d{4})_(?<program_hash>\h{8})_source\.cl/
    PROGRAM_BUILD_OPTIONS_REGEX = /CLI_(?<program_number>\d{4})_(?<program_hash>\h{8})_(?<compile_number>\d{4})_(?<options_hash>\h{8})_options.txt/
    BINARY_BUFFER_ARG_DUMP = /Enqueue_(?<enqueue_number>\d+)_Kernel_(?<kernel_name>\w+?)_Arg_(?<argument_number>\d+)_Buffer_(?<buffer_number>\d+)\.bin/
    SET_ARG_VALUE_DUMP = /SetKernelArg_(?<enqueue_number>\d+)_Kernel_(?<kernel_name>\w+?)_Arg_(?<argument_number>\d+)\.bin/
    MEMDUMP_PRE_DIR = "memDumpPreEnqueue"
    MEMDUMP_POST_DIR = "memDumpPostEnqueue"
    MEMDUMP_ARG_DIR = "SetKernelArg"

    register_callback(CLILoader::CL::SetKernelArg) { |event|
      index = event.infos[:index]
      kernel = event.infos[:kernel]
      filename = "SetKernelArg_%04d_Kernel_%s_Arg_%d.bin" % [event.date, kernel.infos[:kernel_name], index]
      path = File::join(dir, MEMDUMP_ARG_DIR, filename)
      kernel.state[:arg_files][index] = nil
      kernel.state[:arg_files][index] = path if File.exist?(path)
    }

    register_callback(CLILoader::CL::EnqueueNDRangeKernel) { |event|
      kernel = event.infos[:kernel]
      regex = /Enqueue_#{"%04d" % event.date}_Kernel_#{kernel.infos[:kernel_name]}_Arg_(?<argument_number>\d+)_Buffer_(?<buffer_number>\d+)\.bin/
      l = lambda { |dump_dir, state|
        kernel.state[state] = []
        Dir::open(File::join(dir, dump_dir)) { |d|
          d.each { |filename|
            match = filename.match regex
            if match
              argument_number = match[:argument_number].to_i
              kernel.state[state][argument_number] = File::join(dir, dump_dir, filename)
            end
          }
        }
      }
      l.call(MEMDUMP_PRE_DIR, :arg_buff_files_in)
      l.call(MEMDUMP_POST_DIR, :arg_buff_files_out)
    }

    register_callback(CLILoader::CL::CreateProgramWithSource) { |event|
      program = event.returned
      program_number = event.infos[:"program number"]
      regex = /CLI_#{program_number}_(?<program_hash>\h{8})_source\.cl/
      program.state[:source] = nil
      Dir::open(dir) { |d|
        d.each { |filename|
          match = filename.match regex
          if match
            program.state[:source] = File::join(dir, filename)
          end
        }
      }
    }

    register_callback(CLILoader::CL::BuildProgram) { |event|
      program = event.infos[:program]
      program_number = program.infos[:"program number"]
      regex = /CLI_#{program_number}_(?<program_hash>\h{8})_#{"%04d" % (program.state[:compile_count] - 1)}_(?<options_hash>\h{8})_options.txt/
      program.state[:build_options] = nil
      Dir::open(dir) { |d|
        d.each { |filename|
          match = filename.match regex
          if match
            program.state[:build_options] = File::join(dir, filename)
          end
        }
      }
    }

    def self.activate(dir_path)
      @dir = dir_path
      CLILoader::State.activate
      super()
    end

    def self.deactivate
      @dir = nil
      CLILoader::State.deactivate
      super
    end

  end

end
