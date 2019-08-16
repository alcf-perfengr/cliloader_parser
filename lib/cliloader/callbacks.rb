module CLILoader

  module Callbacks

    def self.extended(mod)
      mod.const_set(:"#{mod.name.split("::").last.upcase}_CALLBACKS", Hash::new { |h, k| h[k] = [] })
    end

    def register_callback(type, &callback)
      const_get(:"#{name.split("::").last.upcase}_CALLBACKS")[type].push callback
    end

    def activate
      const_get(:"#{name.split("::").last.upcase}_CALLBACKS").each { |klass, callback_list|
        callback_list.each { |callback|
          klass.register_callback(callback)
        }
      }
    end

    def deactivate
      const_get(:"#{name.split("::").last.upcase}_CALLBACKS").each { |klass, callback_list|
        callback_list.each { |callback|
          klass.unregister_callback(callback)
        }
      }
    end

  end

end
