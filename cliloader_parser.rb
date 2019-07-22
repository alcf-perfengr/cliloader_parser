module CLILoaderParser

  module CL

    module Parsable
      attr_accessor :creator

      def tag
        self.cl_name.downcase
      end

      def cl_name
        self.name.split("::").last
      end

    end

    class Obj
      attr_reader :clid
      attr_accessor :refcount

      def initialize(clid)
        @clid = clid
        @refcount = 1
      end

      def self.inherited(subclass)
        subclass.extend(Parsable)
        subclass.instance_variable_set(:@creator, "clCreate#{subclass.cl_name}")
      end
    end

    class Context < Obj
    end

  end

  module Parser

    CREATORS = {}
    OBJECTS = {}

    def self.parser_prog
      return @parser_prog
    end

    def self.register(klass)
      CREATORS[klass.creator] = klass
    end

    def self.generate
      @parser_prog = <<EOF
    def self.parse_block(call_line, return_line)
      case call_line
EOF
      CREATORS.each { |func, klass|
        @parser_prog << <<EOF
      when /#{func}/
        return_line =~ /#{func}: returned (0x\\h+) /
        OBJECTS[$1] = #{klass.name}::new($1)
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

  Parser.register(CL::Context)
  Parser.generate

end
