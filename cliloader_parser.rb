module CLILoaderParser

  module Parser

    CLASSES = []

    def self.register(klass)
      CLASSES.push klass
    end

  end

  module CL

    module Parsable
      attr_reader :creators
      attr_reader :creators_params
      attr_reader :creators_returns
      attr_reader :releaser
      attr_reader :releaser_tag
      attr_reader :retainer
      attr_reader :retainer_tag

      def tag
        self.cl_name.downcase
      end

      def cl_name
        self.name.split("::").last
      end

    end

    class Obj
      attr_reader :clid
      attr_accessor :reference_count
      attr_reader :creation_date
      attr_accessor :deletion_date

      def initialize(clid, creation_date, **infos)
        @clid = clid
        @reference_count = 1
        @creation_date = creation_date
        @deletion_date = nil
        @infos = infos
      end

      def self.inherited(subclass)
        subclass.extend(Parsable)
        subclass.instance_variable_set(:@creators, [ "clCreate#{subclass.cl_name}" ])
        subclass.instance_variable_set(:@creators_params, [{}])
        subclass.instance_variable_set(:@creators_returns, [{}])
        subclass.instance_variable_set(:@releaser, "clRelease#{subclass.cl_name}")
        subclass.instance_variable_set(:@releaser_tag, subclass.tag)
        subclass.instance_variable_set(:@retainer, "clRetain#{subclass.cl_name}")
        subclass.instance_variable_set(:@retainer_tag, subclass.tag)
        CLILoaderParser::Parser.register(subclass)
      end
    end

    class Flags
    end

    class Context < Obj
      @creators_params = [ { num_devices: Integer } ]
    end

    class CommandQueue < Obj
      @creators_params = [ { context: Context, properties: Flags } ]
      @releaser_tag = "command_queue"
      @retainer_tag = "command_queue"
    end

    class Program < Obj
      @creators = [ "clCreateProgramWithSource" ]
      @creators_params = [ { context: Context, count: Integer } ]
      @creators_returns = [ { :"program number" => Integer } ]
    end

    class Kernel < Obj
      @creators_params = [ { program: Program, kernel_name: String } ]
    end

    class Buffer < Obj
      @creators_params = [ { context: Context, flags: Flags, size: Integer } ]
      @releaser = "clReleaseMemObject"
      @releaser_tag = "mem"
      @retainer = "clRetainMemObject"
      @retainer_tag = "mem"
    end

  end

  module Parser

    OBJECTS = {}

    def self.parser_prog
      return @parser_prog
    end

    def self.generate
      @parser_prog = <<EOF
    def self.parse_block(call_line, return_line)
      case call_line
EOF
      CLASSES.each { |klass|
        klass.creators.each_with_index { |func, index|
          params = klass.creators_params[index]
          returns = klass.creators_returns[index]
          @parser_prog << <<EOF
      when /#{func}/
        return_line =~ /returned (0x\\h+)/
        clid = $1
        call_line =~ /EnqueueCounter: (\\d+)/
        creation_date = $1
        args = {}
EOF
          param_parser = lambda { |stream, param, kind|
            if kind < CLILoaderParser::CL::Obj
              @parser_prog << <<EOF
        #{stream} =~ /#{param} = (0x\\h+)/
        args[:"#{param}"] = OBJECTS[$1] if $&
EOF
            elsif kind == Integer
              @parser_prog << <<EOF
        #{stream} =~ /#{param} = (\\d+)/
        args[:"#{param}"] = $1.to_i if $&
EOF
            elsif kind == String
              @parser_prog << <<EOF
        #{stream} =~ /#{param} = (\\w+)/
        args[:"#{param}"] = $1 if $&
EOF
            elsif kind == CLILoaderParser::CL::Flags
              @parser_prog << <<EOF
        #{stream} =~ /#{param} = \\w* \\((\\d+)\\)/
        args[:"#{param}"] = $1.to_i if $&
EOF
            end
          }
          params.each { |param, kind| param_parser.call("call_line", param, kind) }
          returns.each { |param, kind| param_parser.call("return_line", param, kind) }
          @parser_prog << <<EOF
          OBJECTS[clid] = #{klass.name}::new(clid, creation_date, **args)
EOF
        }
      
        func = klass.releaser
        tag = klass.releaser_tag
        @parser_prog << <<EOF
      when /#{func}/
        call_line =~ /#{tag} = (0x\\h+)/
        clid = $1
        OBJECTS[clid].reference_count -= 1
        if OBJECTS[clid].reference_count == 0
          call_line =~ /EnqueueCounter: (\\d+)/
          OBJECTS[clid].deletion_date = $1
        end
EOF
        func = klass.retainer
        tag = klass.releaser_tag
        @parser_prog << <<EOF
      when /#{func}/
        call_line =~ /#{tag} = (0x\\h+)/
        clid = $1
        OBJECTS[clid].reference_count += 1
EOF
      }
      @parser_prog << <<EOF
      end
    end
EOF
      eval(@parser_prog)
    end

    def self.parse_log(logfile)
      logfile.lazy.select { |l|
        l.match(/^<<<</) || l.match(/^>>>>/)
      }.each_slice(2) { |call_line, return_line|
        parse_block(call_line, return_line)
      }
    end

  end

  Parser.generate

end
