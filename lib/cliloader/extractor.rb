require 'fileutils'

module CLILoader

  module Extractor

    def self.save_kernel_data(dirpath, kernels, enqueues, set_args, buffer_inputs, buffer_outputs)
      kernels.each { |k|
        kernel_dirpath = File.join(dirpath, k.infos[:kernel_name])
        Dir::mkdir(kernel_dirpath) unless Dir.exist?(kernel_dirpath)
        kernel_enqueues = enqueues.select { |e| e.infos[:kernel] == k }
        kernel_enqueues.each { |e|
          enqueue_dirpath = File.join(kernel_dirpath, "%04d" % e.date)
          Dir::mkdir(enqueue_dirpath) unless Dir.exist?(enqueue_dirpath)
        }
      }
    end

    def self.extract_kernels(dir, objects, events, program_sources, buffer_inputs, buffer_outputs)
      programs = []
      objects.each { |k, obj_list|
        obj_list.each { |obj|
          programs.push obj if obj.kind_of? CLILoader::CL::Program
        }
      }
      kernels = []
      objects.each { |k, obj_list|
        obj_list.each { |obj|
          kernels.push obj if obj.kind_of? CLILoader::CL::Kernel
        }
      }
      enqueues = buffer_inputs.collect { |k, (ev, arg_num)| ev }
      enqueues += buffer_outputs.collect { |k, (ev, arg_num)| ev }
      enqueues.uniq!
      set_args = events.select { |e| e.kind_of? CLILoader::CL::SetKernelArg }
       
      programs.each { |p|
        number = p.infos[:"program number"]
        dirpath = File.join(dir.path, "%04d" % number)
        Dir::mkdir(dirpath) unless Dir.exist?(dirpath)
        src = program_sources.find { |k, v| v.returned == p }
        FileUtils.cp src.first, File.join(dirpath, "source.cl")
        prog_kernels = kernels.select { |k| k.infos[:program] == p }

        save_kernel_data(dirpath, prog_kernels, enqueues, set_args, buffer_inputs, buffer_outputs) 
      }
    end

  end

end
