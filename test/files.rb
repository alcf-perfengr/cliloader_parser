class TestFiles < Minitest::Test

  def test_3D
    objects = nil
    events = nil
    File::open("./3D/clintercept_log.txt", "r") { |f|
      objects, events = CLILoader::Parser.parse(f)
    }
    Dir::open("./3D/") { |d|
      CLILoader::Files::match_files(d, events)
      assert_equal( 1, CLILoader::Files.program_sources.size )
      assert_equal( 3, CLILoader::Files.buffer_inputs.size )
      assert_equal( 3, CLILoader::Files.buffer_outputs.size )
    }
  end

end
