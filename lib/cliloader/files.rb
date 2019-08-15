module CLILoader

  module Files


    class << self
      attr_reader :program_sources
      attr_reader :program_build_options
      attr_reader :buffer_inputs
      attr_reader :buffer_outputs
      attr_reader :set_arg_values
      attr_accessor :dir
    end

    PROGRAM_SOURCE_REGEX = /CLI_(?<program_number>\d{4})_(?<program_hash>\h{8})_source\.cl/
    PROGRAM_BUILD_OPTIONS_REGEX = /CLI_(?<program_number>\d{4})_(?<program_hash>\h{8})_(?<compile_number>\d{4})_(?<options_hash>\h{8})_options.txt/
    BINARY_BUFFER_ARG_DUMP = /Enqueue_(?<enqueue_number>\d+)_Kernel_(?<kernel_name>\w+?)_Arg_(?<argument_number>\d+)_Buffer_(?<buffer_number>\d+)\.bin/
    SET_ARG_VALUE_DUMP = /SetKernelArg_(?<enqueue_number>\d+)_Kernel_(?<kernel_name>\w+?)_Arg_(?<argument_number>\d+)\.bin/
    MEMDUMP_PRE_DIR = "memDumpPreEnqueue"
    MEMDUMP_POST_DIR = "memDumpPostEnqueue"
    MEMDUMP_ARG_DIR = "SetKernelArg"

    CLILoader::State::STATE_CALLBACKS[CLILoader::CL::SetKernelArg].push(
      lambda { |event|
        index = event.infos[:index]
        kernel = event.infos[:kernel]
        filename = "SetKernelArg_%04d_Kernel_%s_Arg_%d.bin" % [event.date, kernel.infos[:kernel_name], index]
        path = File::join(dir, MEMDUMP_ARG_DIR, filename)
        kernel.state[:arg_files][index] = nil
        kernel.state[:arg_files][index] = path if File.exist?(path)
      }
    )

    CLILoader::State::STATE_CALLBACKS[CLILoader::CL::EnqueueNDRangeKernel].push(
      lambda { |event|
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
    )

    CLILoader::State::STATE_CALLBACKS[CLILoader::CL::CreateProgramWithSource].push(
      lambda { |event|
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
    )

    CLILoader::State::STATE_CALLBACKS[CLILoader::CL::BuildProgram].push(
      lambda { |event|
        program = event.infos[:program]
        program_number = program.infos[:"program number"]
        regex = /CLI_#{program_number}_(?<program_hash>\h{8})_#{"%04d" % program.state[:compile_number]}_(?<options_hash>\h{8})_options.txt/
        program.state[:build_options] = nil
        Dir::open(dir) { |d|
          d.each { |filename|
            match = filename.match regex
            if match
              program.state[:build_options] = File::join(dir, filename)
            end
          }
        }
        program.state[:compile_number] += 1
      }
    )

    def self.match_program_source(dir, events)
      create_program_with_source_evts = events.select { |e|
        e.kind_of? CLILoader::CL::CreateProgramWithSource
      }
      dir.each { |file_name|
        match = file_name.match PROGRAM_SOURCE_REGEX
        if match
          evt = create_program_with_source_evts.find { |e|
            e.infos[:"program number"] == match[:program_number]
          }
          @program_sources[File.join(dir.path,file_name)] = evt if evt
        end
      }
    end

    def self.match_program_build_options(dir, events)
      build_program_evts = events.select { |e|
        e.kind_of? CLILoader::CL::BuildProgram
      }
      dir.each { |file_name|
        match = file_name.match PROGRAM_BUILD_OPTIONS_REGEX
        if match
          evts = events.select { |e|
            e.infos[:"program number"] == match[:program_number]
          }
          compile_number = match[:compile_number].to_i
          evt = evts[compile_number]
          @program_build_options[File.join(dir.path,file_name)] = [evt, compile_number] if evt
        end
      }
    end

    def self.match_buffer_binary_helper(dir, events, store, dir_name, enqueue_kernel_evts)
      begin
        dirpath = File.join(dir.path, dir_name)
        Dir.open(dirpath) { |d|
          d.each { |file_name|
            match = file_name.match BINARY_BUFFER_ARG_DUMP
            if $&
              date = match[:enqueue_number].to_i
              index = match[:argument_number].to_i
              evt = enqueue_kernel_evts.find { |e|
                e.date == date
              }
              store[File.join(dirpath, file_name)] = [ evt, index ]
            end
          }
        }
      rescue Errno::ENOENT
      end
    end

    def self.match_buffer_binary(dir, events)
      enqueue_kernel_evts = events.select { |e|
        e.kind_of? CLILoader::CL::EnqueueNDRangeKernel
      }
      match_buffer_binary_helper(dir, events, @buffer_inputs, MEMDUMP_PRE_DIR, enqueue_kernel_evts)
      match_buffer_binary_helper(dir, events, @buffer_outputs, MEMDUMP_POST_DIR, enqueue_kernel_evts)
    end

    def self.match_set_arg_values(dir, events)
      set_arg_evts = events.select { |e|
        e.kind_of? CLILoader::CL::SetKernelArg
      }.reverse
      begin
        dirpath = File.join(dir.path, MEMDUMP_ARG_DIR)
        Dir.open(dirpath) { |d|
          d.each { |file_name|
            match = file_name.match SET_ARG_VALUE_DUMP
            if match
              date = match[:enqueue_number].to_i
              index = match[:argument_number].to_i
              matching_events = set_arg_evts.select { |evt|
                evt.date == date &&
                evt.infos[:kernel].infos[:kernel_name] == match[:kernel_name] &&
                evt.infos[:index] == index
              }
              @set_arg_values[File.join(dirpath, file_name)] = matching_events
            end
          }
        } 
      rescue Errno::ENOENT
      end
    end

    def self.match_files(dir, events)
      @program_sources = {}
      @program_build_options = {}
      @buffer_inputs = {}
      @buffer_outputs = {}
      @set_arg_values = {}
      match_program_source(dir, events)
      match_program_build_options(dir, events)
      match_buffer_binary(dir, events)
      match_set_arg_values(dir, events)
      [@program_sources, @program_build_options, @buffer_inputs, @buffer_outputs, @set_arg_values]
    end

  end

end
