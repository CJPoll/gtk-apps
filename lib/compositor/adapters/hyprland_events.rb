# frozen_string_literal: true

require 'socket'

module Compositor
  module Adapters
    # Streams Hyprland's event socket (.socket2.sock). Hyprland writes one
    # "EVENT>>DATA" line per state change; this adapter turns those lines into
    # handler calls delivered on the GTK main thread.
    class HyprlandEvents
      def initialize
        @handlers = {}
        @thread = nil
      end

      def on(event_name, &handler)
        (@handlers[event_name.to_s] ||= []) << handler
        self
      end

      def start
        return self if @thread

        path = socket_path
        unless path
          warn 'HyprlandEvents: no Hyprland instance in the environment; not watching for events.'
          return self
        end

        @thread = Thread.new { listen(path) }
        self
      end

      def stop
        @thread&.kill
        @thread = nil
      end

      private

      def socket_path
        signature = ENV.fetch('HYPRLAND_INSTANCE_SIGNATURE', nil)
        runtime_dir = ENV.fetch('XDG_RUNTIME_DIR', nil)
        return nil unless signature && runtime_dir

        File.join(runtime_dir, 'hypr', signature, '.socket2.sock')
      end

      def listen(path)
        UNIXSocket.open(path) do |socket|
          while (line = socket.gets)
            dispatch(line.chomp)
          end
        end
      rescue StandardError => e
        warn "HyprlandEvents: event stream closed: #{e.message}"
      end

      def dispatch(line)
        event_name, data = line.split('>>', 2)
        handlers = @handlers.fetch(event_name, [])
        return if handlers.empty?

        # The socket has its own thread; GTK work must happen on the main loop.
        GLib::Idle.add do
          handlers.each { |handler| invoke(handler, event_name, data.to_s) }
          false
        end
      end

      # An exception raised inside an idle callback unwinds out of the GLib
      # main loop and takes the process with it, so a single failed handler
      # must not escape here.
      def invoke(handler, event_name, data)
        handler.call(data)
      rescue StandardError => e
        warn "HyprlandEvents: #{event_name} handler failed: #{e.class}: #{e.message}"
        warn e.backtrace.take(5).join("\n")
      end
    end
  end
end
