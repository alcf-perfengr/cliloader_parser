module CLILoader

  module State

    STATE_CALLBACKS = Hash::new { |h, k| h[k] = [] }

    STATE_CALLBACKS[CLILoader::CL::SetKernelArg].push(
      lambda { |event|
        if event.return_code == "CL_SUCCESS"
          event.infos[:kernel].state[:args][event.infos[:index]] = event
        end
      }
    )

    def self.activate_states
      STATE_CALLBACKS.each { |klass, callback_list|
        callback_list.each { |callback|
          klass.register_callback(callback)
        }
      }
    end

    def self.deactivate_states
      STATE_CALLBACKS.each { |klass, callback_list|
        callback_list.each { |callback|
          klass.unregister_callback(callback)
        }
      }
    end

  end

end
