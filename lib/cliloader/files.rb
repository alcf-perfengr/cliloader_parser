module CLILoader

  module Files

    class << self
      attr_reader :program_sources
      attr_reader :buffer_inputs
      attr_reader :buffer_outputs
      attr_reader :set_arg_values
    end

    PROGRAM_SOURCE_REGEX = /CLI_(\d{4})_(\h{8})_source\.cl/
    BINARY_BUFFER_ARG_DUMP = /Enqueue_(\d+)_Kernel_(\w+?)_Arg_(\d+)_Buffer_(\d+)\.bin/
    SET_ARG_VALUE_DUMP = /SetKernelArg_(\d+)_Kernel_(\w+?)_Arg_(\d+)\.bin/
    MEMDUMP_PRE_DIR = "memDumpPreEnqueue"
    MEMDUMP_POST_DIR = "memDumpPostEnqueue"
    MEMDUMP_ARG_DIR = "SetKernelArg"

    def self.match_program_source(dir, events)
      create_program_with_source_evts = events.select { |e|
        e.kind_of? CLILoader::CL::CreateProgramWithSource
      }
      dir.each { |file_name|
        file_name =~ PROGRAM_SOURCE_REGEX
        if $&
          program_number = $1
          program_hash = $2
          evt = create_program_with_source_evts.find { |e|
            e.infos[:"program number"] == program_number
          }
          @program_sources[File.join(dir.path,file_name)] = evt if evt
        end
      }
    end

    def self.match_buffer_binary_helper(dir, events, store, dir_name, enqueue_kernel_evts)
      begin
        dirpath = File.join(dir.path, dir_name)
        Dir.open(dirpath) { |d|
          d.each { |file_name|
            file_name =~ BINARY_BUFFER_ARG_DUMP
            if $&
              date = $1.to_i
              index = $3.to_i
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
            file_name =~ SET_ARG_VALUE_DUMP
            if $&
              date = $1.to_i
              kernel_name = $2
              index = $3.to_i
              matching_events = set_arg_evts.select { |evt|
                evt.date == date &&
                evt.infos[:kernel].infos[:kernel_name] == kernel_name &&
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
      @buffer_inputs = {}
      @buffer_outputs = {}
      @set_arg_values = {}
      match_program_source(dir, events)
      match_buffer_binary(dir, events)
      match_set_arg_values(dir, events)
      [@program_sources, @buffer_inputs, @buffer_outputs, @set_arg_values]
    end

  end

end
