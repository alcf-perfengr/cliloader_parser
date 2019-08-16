require 'fileutils'
require 'set'

module CLILoader

  module Extractor
    extend Callbacks

    def self.activate(file_dir_path, dir_path)
      @dir = dir_path
      CLILoader::Files::activate(file_dir_path)
      super()
    end

    def self.deactivate
      @dir = nil
      CLILoader::Files::deactivate
      super
    end

    class << self
      attr_accessor :dir
    end

    register_callback(CLILoader::CL::CreateProgramWithSource) { |event|
      program = event.returned
      program_number = event.infos[:"program number"]
      path = File::join(dir, "%04d" % program_number)
      Dir.mkdir(path) unless Dir.exist?(path)
      FileUtils.cp program.state[:source], File.join(path, "source.cl")
    }

    register_callback(CLILoader::CL::BuildProgram) { |event|
      program = event.infos[:program]
      program_number = program.infos[:"program number"]
      compile_number = program.state[:compile_count] - 1
      path = File::join(dir, "%04d" % program_number, "%04d" % compile_number)
      Dir.mkdir(path) unless Dir.exist?(path)
      FileUtils.cp program.state[:build_options], File.join(path, "options.txt") if program.state[:build_options]
    }

    register_callback(CLILoader::CL::EnqueueNDRangeKernel) { |event|
      kernel = event.infos[:kernel]
      compile_number = kernel.state[:program_compile_number]
      program_number = kernel.infos[:program].infos[:"program number"]
      kernel_name = kernel.infos[:kernel_name]
      kernel_path = File::join(dir, "%04d" % program_number, "%04d" % compile_number, kernel_name)
      if kernel.state[:arg_buff_files_in].compact.length > 0
        Dir.mkdir(kernel_path) unless Dir.exist?(kernel_path)
        path = File::join(kernel_path, "%04d" % event.date)
        Dir.mkdir(path) unless Dir.exist?(path)
        save_kernel_work_data(path, event)
        kernel.state[:args].each { |set_arg_event|
          index = set_arg_event.infos[:index]
          index_str = "%02d" % index
          if set_arg_event.infos[:value].class < CLILoader::CL::Mem
            FileUtils.cp kernel.state[:arg_buff_files_in][index], File.join(path, "#{index_str}.buffer.in")
            FileUtils.cp kernel.state[:arg_buff_files_out][index], File.join(path, "#{index_str}.buffer.out")
          else
            file_path = File.join(path, "#{index_str}.in")
            if kernel.state[:arg_files][index]
              FileUtils.cp kernel.state[:arg_files][index], file_path
            else
              File.open( file_path,"wb") { |f|
                f.write([set_arg_event.infos[:size]].pack("J"))
              }
            end
          end
        }
      end
    }

    def self.dump_kernel_work_data_info(dirpath, enqueue, info)
      if enqueue.infos[info]
        File::open(File::join(dirpath, info.to_s), "wb") { |f|
          f.write(enqueue.infos[info].pack("Q*"))
        }
      end
    end

    def self.save_kernel_work_data(dirpath, enqueue)
      [:global_work_offset, :global_work_size, :local_work_size].each { |info|
        dump_kernel_work_data_info(dirpath, enqueue, info)
      }
    end

  end

end
