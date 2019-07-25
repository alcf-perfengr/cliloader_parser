class TestExtractor < Minitest::Test

  def test_3D
    objects = nil
    events = nil
    File::open("./3D/clintercept_log.txt", "r") { |f|
      objects, events = CLILoader::Parser.parse(f)
    }
    program_sources = nil
    buffer_inputs = nil
    buffer_outputs = nil
    Dir::open("./3D/") { |d|
      program_sources, buffer_inputs, buffer_outputs = CLILoader::Files::match_files(d, events)
    }
    FileUtils.remove_entry("./3D_output") if Dir::exist?("./3D_output")
    Dir::mkdir("./3D_output")
    Dir::open("./3D_output") { |d|
      CLILoader::Extractor.extract_kernels(d, objects, events, program_sources, buffer_inputs, buffer_outputs)
    }
  end

end
