require 'fileutils'
require 'set'

module CLILoader

  module Extractor

    def self.save_kernel_data(dirpath, kernels, enqueues, set_args, buffer_inputs, buffer_outputs, arg_values)
      kernels.each { |k|
        kernel_dirpath = File.join(dirpath, k.infos[:kernel_name])
        Dir::mkdir(kernel_dirpath) unless Dir.exist?(kernel_dirpath)
        kernel_enqueues = enqueues.select { |enqueue| enqueue.infos[:kernel] == k }
        kernel_enqueues.each { |enqueue|
          enqueue_dirpath = File.join(kernel_dirpath, "%04d" % enqueue.date)
          Dir::mkdir(enqueue_dirpath) unless Dir.exist?(enqueue_dirpath)
          arg_set = Set::new
          buffer_inputs.each do |file_name, (evt, arg_number)|
            if evt == enqueue
              FileUtils.cp file_name, File.join(enqueue_dirpath, "%02d.buffer.in" % arg_number)
              arg_set.add arg_number
            end
          end
          buffer_outputs.select do |file_name, (evt, arg_number)|
            if evt == enqueue
              FileUtils.cp file_name, File.join(enqueue_dirpath, "%02d.buffer.out" % arg_number)
              arg_set.add arg_number
            end
          end
          kernel_set_args = set_args.select { |evt| evt.infos[:kernel] == k }
          arg_number_list = kernel_set_args.collect { |evt| evt.infos[:index] }.uniq
          remaining_args = arg_number_list - arg_set.to_a
          remaining_args.each { |index|
            set_arg = kernel_set_args.find { |evt|
              evt.date <= enqueue.date && evt.infos[:index] == index
            }
            file_name, _ = arg_values.find { |file_name, event_list| event_list.include?(set_arg) }
            FileUtils.cp file_name, File.join(enqueue_dirpath, "%02d.in" % index)
          }
        }
      }
    end

    def self.extract_kernels(dir, objects, events, program_sources, buffer_inputs, buffer_outputs, arg_values)
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
      #reverse set_arg order
      set_args = events.select { |e|
        e.kind_of? CLILoader::CL::SetKernelArg
      }.reverse
       
      programs.each { |p|
        number = p.infos[:"program number"]
        dirpath = File.join(dir.path, "%04d" % number)
        Dir::mkdir(dirpath) unless Dir.exist?(dirpath)
        src = program_sources.find { |k, v| v.returned == p }
        FileUtils.cp src.first, File.join(dirpath, "source.cl")
        prog_kernels = kernels.select { |k| k.infos[:program] == p }

        save_kernel_data(dirpath, prog_kernels, enqueues, set_args, buffer_inputs, buffer_outputs, arg_values) 
      }
    end

  end

end
