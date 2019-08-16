class TestExtractor < Minitest::Test

  def test_3D
    objects = nil
    events = nil
    begin
    FileUtils.remove_entry("./3D_output") if Dir::exist?("./3D_output")
    Dir::mkdir("./3D_output")
    File::open("./3D/clintercept_log.txt", "r") { |f|
      CLILoader::Extractor::activate("./3D/", "./3D_output/")
      objects, events = CLILoader::Parser.parse(f)
    }
    assert_equal( <<EOF, `find 3D_output | sort`)
3D_output
3D_output/0000
3D_output/0000/0000
3D_output/0000/0000/hotspotOpt1
3D_output/0000/0000/hotspotOpt1/0050
3D_output/0000/0000/hotspotOpt1/0050/00.buffer.in
3D_output/0000/0000/hotspotOpt1/0050/00.buffer.out
3D_output/0000/0000/hotspotOpt1/0050/01.buffer.in
3D_output/0000/0000/hotspotOpt1/0050/01.buffer.out
3D_output/0000/0000/hotspotOpt1/0050/02.buffer.in
3D_output/0000/0000/hotspotOpt1/0050/02.buffer.out
3D_output/0000/0000/hotspotOpt1/0050/03.in
3D_output/0000/0000/hotspotOpt1/0050/04.in
3D_output/0000/0000/hotspotOpt1/0050/05.in
3D_output/0000/0000/hotspotOpt1/0050/06.in
3D_output/0000/0000/hotspotOpt1/0050/07.in
3D_output/0000/0000/hotspotOpt1/0050/08.in
3D_output/0000/0000/hotspotOpt1/0050/09.in
3D_output/0000/0000/hotspotOpt1/0050/10.in
3D_output/0000/0000/hotspotOpt1/0050/11.in
3D_output/0000/0000/hotspotOpt1/0050/12.in
3D_output/0000/0000/hotspotOpt1/0050/13.in
3D_output/0000/0000/hotspotOpt1/0050/global_work_size
3D_output/0000/0000/hotspotOpt1/0050/local_work_size
3D_output/0000/source.cl
EOF
    ensure
      CLILoader::Extractor::deactivate
    end
  end

  def test_bfs
    objects = nil
    events = nil
    begin
    FileUtils.remove_entry("./bfs_output") if Dir::exist?("./bfs_output")
    Dir::mkdir("./bfs_output")
    File::open("./bfs/clintercept_log.txt", "r") { |f|
      CLILoader::Extractor::activate("./bfs/", "./bfs_output/")
      objects, events = CLILoader::Parser.parse(f)
    }
    assert_equal( <<EOF, `find bfs_output | sort`)
bfs_output
bfs_output/0000
bfs_output/0000/0000
bfs_output/0000/0000/BFS_1
bfs_output/0000/0000/BFS_1/0044
bfs_output/0000/0000/BFS_1/0044/00.buffer.in
bfs_output/0000/0000/BFS_1/0044/00.buffer.out
bfs_output/0000/0000/BFS_1/0044/01.buffer.in
bfs_output/0000/0000/BFS_1/0044/01.buffer.out
bfs_output/0000/0000/BFS_1/0044/02.buffer.in
bfs_output/0000/0000/BFS_1/0044/02.buffer.out
bfs_output/0000/0000/BFS_1/0044/03.buffer.in
bfs_output/0000/0000/BFS_1/0044/03.buffer.out
bfs_output/0000/0000/BFS_1/0044/04.buffer.in
bfs_output/0000/0000/BFS_1/0044/04.buffer.out
bfs_output/0000/0000/BFS_1/0044/05.buffer.in
bfs_output/0000/0000/BFS_1/0044/05.buffer.out
bfs_output/0000/0000/BFS_1/0044/06.in
bfs_output/0000/0000/BFS_1/0044/global_work_size
bfs_output/0000/0000/BFS_1/0044/local_work_size
bfs_output/0000/0000/BFS_2
bfs_output/0000/0000/BFS_2/0045
bfs_output/0000/0000/BFS_2/0045/00.buffer.in
bfs_output/0000/0000/BFS_2/0045/00.buffer.out
bfs_output/0000/0000/BFS_2/0045/01.buffer.in
bfs_output/0000/0000/BFS_2/0045/01.buffer.out
bfs_output/0000/0000/BFS_2/0045/02.buffer.in
bfs_output/0000/0000/BFS_2/0045/02.buffer.out
bfs_output/0000/0000/BFS_2/0045/03.buffer.in
bfs_output/0000/0000/BFS_2/0045/03.buffer.out
bfs_output/0000/0000/BFS_2/0045/04.in
bfs_output/0000/0000/BFS_2/0045/global_work_size
bfs_output/0000/0000/BFS_2/0045/local_work_size
bfs_output/0000/source.cl
EOF
    ensure
      CLILoader::Extractor::deactivate
    end
  end

  def test_lud
    objects = nil
    events = nil
    begin
    FileUtils.remove_entry("./lud_output") if Dir::exist?("./lud_output")
    Dir::mkdir("./lud_output")
    File::open("./lud/clintercept_log.txt", "r") { |f|
      CLILoader::Extractor::activate("./lud/", "./lud_output/")
      objects, events = CLILoader::Parser.parse(f)
    }
    assert_equal( <<EOF, `find lud_output | sort`)
lud_output
lud_output/0000
lud_output/0000/0000
lud_output/0000/0000/lud_diagonal
lud_output/0000/0000/lud_diagonal/0056
lud_output/0000/0000/lud_diagonal/0056/00.buffer.in
lud_output/0000/0000/lud_diagonal/0056/00.buffer.out
lud_output/0000/0000/lud_diagonal/0056/01.in
lud_output/0000/0000/lud_diagonal/0056/02.in
lud_output/0000/0000/lud_diagonal/0056/03.in
lud_output/0000/0000/lud_diagonal/0056/global_work_size
lud_output/0000/0000/lud_diagonal/0056/local_work_size
lud_output/0000/0000/lud_diagonal/0059
lud_output/0000/0000/lud_diagonal/0059/00.buffer.in
lud_output/0000/0000/lud_diagonal/0059/00.buffer.out
lud_output/0000/0000/lud_diagonal/0059/01.in
lud_output/0000/0000/lud_diagonal/0059/02.in
lud_output/0000/0000/lud_diagonal/0059/03.in
lud_output/0000/0000/lud_diagonal/0059/global_work_size
lud_output/0000/0000/lud_diagonal/0059/local_work_size
lud_output/0000/0000/lud_internal
lud_output/0000/0000/lud_internal/0058
lud_output/0000/0000/lud_internal/0058/00.buffer.in
lud_output/0000/0000/lud_internal/0058/00.buffer.out
lud_output/0000/0000/lud_internal/0058/01.in
lud_output/0000/0000/lud_internal/0058/02.in
lud_output/0000/0000/lud_internal/0058/03.in
lud_output/0000/0000/lud_internal/0058/04.in
lud_output/0000/0000/lud_internal/0058/global_work_size
lud_output/0000/0000/lud_internal/0058/local_work_size
lud_output/0000/0000/lud_perimeter
lud_output/0000/0000/lud_perimeter/0057
lud_output/0000/0000/lud_perimeter/0057/00.buffer.in
lud_output/0000/0000/lud_perimeter/0057/00.buffer.out
lud_output/0000/0000/lud_perimeter/0057/01.in
lud_output/0000/0000/lud_perimeter/0057/02.in
lud_output/0000/0000/lud_perimeter/0057/03.in
lud_output/0000/0000/lud_perimeter/0057/04.in
lud_output/0000/0000/lud_perimeter/0057/05.in
lud_output/0000/0000/lud_perimeter/0057/global_work_size
lud_output/0000/0000/lud_perimeter/0057/local_work_size
lud_output/0000/0000/options.txt
lud_output/0000/source.cl
EOF
    ensure
      CLILoader::Extractor::deactivate
    end
  end

end
