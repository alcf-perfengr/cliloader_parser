module CLILoader

  module Parser
    class << self
      attr_reader :objects
      attr_reader :events
    end

    CLASSES = []

    def self.register(klass)
      CLASSES.push klass
    end

    def self.parser_prog
      return @parser_prog
    end

    def self.generate

      param_parser = lambda { |stream, param, kind|
        if kind < CLILoader::CL::Obj || kind == CLILoader::CL::Handle
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = (0x\\h+)/
        if $&
          handle = $1
          args[:"#{param}"] = handle
          if @objects.keys.include?(handle)
            obj = @objects[handle].last
            args[:"#{param}"] = @objects[$1].last if obj
          end
        end
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
        elsif kind == CLILoader::CL::Bool
          @parser_prog << <<EOF
          #{stream} =~ /#{param}/
          args[:"#{param}"] = true if $&
EOF
        elsif kind == CLILoader::CL::Flags
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = \\w* \\((\\h+)\\)/
        args[:"#{param}"] = $1.to_i(16) if $&
EOF
        elsif kind == CLILoader::CL::Vector
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = <(.*?)>/
        args[:"#{param}"] = $1.split(" x ").collect(&:strip).collect(&:to_i) if $&
EOF
        elsif kind == CLILoader::CL::NameList
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = (\\[.*?\\])/
        args[:"#{param}"] = $1 if $&
EOF
        elsif kind == CLILoader::CL::Pointer
          @parser_prog << <<EOF
        #{stream} =~ /#{param} = \\(nil\\)/
        if $&
          args[:"#{param}"] = nil
        else
          #{stream} =~ /#{param} = (0x\\h+)/
          args[:"#{param}"] = $1 if $&
        end
EOF
        end
      }

      @parser_prog = <<EOF
    def self.parse_block(call_line, return_line)
      case call_line
EOF
      CLASSES.each { |event|
        call_params = event.call_params
        returns = event.returns
        @parser_prog << <<EOF
      when /#{event.cl_name}/
        call_line =~ /EnqueueCounter: (\\d+)/
        date = $1.to_i
        return_line =~ /-> (\\w+)/
        return_code = $1
        returned = nil
        args = {}
EOF
        if event.returned
          @parser_prog << <<EOF
        return_line =~ /returned (0x\\h+)/
        returned = $1 if $&
EOF
        end
        call_params.each { |param, kind| param_parser.call("call_line", param, kind) }
        returns.each { |param, kind| param_parser.call("return_line", param, kind) }
        @parser_prog << <<EOF
        @events.push #{event.name}::new(date, return_code, returned, **args)
EOF
        }
      @parser_prog << <<EOF
      else
        raise "Unrecognized OpenCL event: '\#{call_line}'!"
      end
    end
EOF
      eval(@parser_prog)
    end

    def self.parse(logfile)
      @objects = Hash::new { |h, k| h[k] = [] }
      @events = []
      
      logfile.lazy.select { |l|
        l.match(/^<<<</) || l.match(/^>>>>/)
      }.each_slice(2) { |call_line, return_line|
        parse_block(call_line, return_line)
      }
      [@objects, @events]
    end

  end

end
