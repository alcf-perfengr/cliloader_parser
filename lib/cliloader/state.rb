module CLILoader

  module State
    extend Callbacks

    register_callback(CLILoader::CL::SetKernelArg) { |event|
      event.infos[:kernel].state[:args][event.infos[:index]] = event
    }

    register_callback(CLILoader::CL::CreateKernel) { |event|
      event.returned.state[:program_compile_number] = event.infos[:program].state[:compile_count] - 1
    }

    register_callback(CLILoader::CL::BuildProgram) { |event|
      event.infos[:program].state[:compile_count] += 1
    }

  end

end
