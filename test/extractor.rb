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
    set_arg_values = nil
    Dir::open("./3D/") { |d|
      program_sources, buffer_inputs, buffer_outputs, set_arg_values = CLILoader::Files::match_files(d, events)
    }
    FileUtils.remove_entry("./3D_output") if Dir::exist?("./3D_output")
    Dir::mkdir("./3D_output")
    Dir::open("./3D_output") { |d|
      CLILoader::Extractor.extract_kernels(d, objects, events, program_sources, buffer_inputs, buffer_outputs, set_arg_values)
    }
    assert_equal( <<EOF, `find 3D_output | sort`)
3D_output
3D_output/0000
3D_output/0000/hotspotOpt1
3D_output/0000/hotspotOpt1/0050
3D_output/0000/hotspotOpt1/0050/00.buffer.in
3D_output/0000/hotspotOpt1/0050/00.buffer.out
3D_output/0000/hotspotOpt1/0050/01.buffer.in
3D_output/0000/hotspotOpt1/0050/01.buffer.out
3D_output/0000/hotspotOpt1/0050/02.buffer.in
3D_output/0000/hotspotOpt1/0050/02.buffer.out
3D_output/0000/hotspotOpt1/0050/03.in
3D_output/0000/hotspotOpt1/0050/04.in
3D_output/0000/hotspotOpt1/0050/05.in
3D_output/0000/hotspotOpt1/0050/06.in
3D_output/0000/hotspotOpt1/0050/07.in
3D_output/0000/hotspotOpt1/0050/08.in
3D_output/0000/hotspotOpt1/0050/09.in
3D_output/0000/hotspotOpt1/0050/10.in
3D_output/0000/hotspotOpt1/0050/11.in
3D_output/0000/hotspotOpt1/0050/12.in
3D_output/0000/hotspotOpt1/0050/13.in
3D_output/0000/hotspotOpt1/0050/global_work_size
3D_output/0000/hotspotOpt1/0050/local_work_size
3D_output/0000/source.cl
EOF
  end

end
