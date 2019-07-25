class TestParser < Minitest::Test
  def test_3D
    File::open("./3D/clintercept_log.txt", "r") { |f|
      objects, events = CLILoader::Parser.parse(f)
      pp objects
      assert_equal( 7, objects.size)
      assert_equal( 1527, events.size)
      objects.each { |_, ol|
        ol.each { |o|
          assert_equal( 105, o.deletion_date)
        }
      }
    }
  end
end
