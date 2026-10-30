# frozen_string_literal: true

module Bar
  module UI
    # NVIDIA VRAM pill: "90% VRAM", with the top VRAM-using apps on hover.
    #
    # `sample:` returns a Domain::Vram::Snapshot, or nil when VRAM cannot be
    # read. It blocks for an nvidia-smi call, so it runs on a worker thread and
    # the result hops back with on_main_thread. The widget stays hidden until
    # the first snapshot arrives, and hides again while none can be read.
    class VramWidget < Gtk::Box
      include GtkKit::Timers

      UPDATE_INTERVAL_SECONDS = 5

      def initialize(sample:)
        super(:horizontal, 0)

        @sample = sample
        @sampling = false

        setup_ui
        refresh
        start_timer
      end

      private

      def setup_ui
        @button = Gtk::Button.new(label: '')
        @button.add_css_class('pill')
        @button.add_css_class('vram')

        append(@button)
        self.visible = false
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { refresh }
      end

      # One sample in flight at a time: a slow driver never piles up threads.
      def refresh
        return if @sampling

        @sampling = true
        Thread.new do
          snapshot = take_sample
          on_main_thread { render(snapshot) }
        end
      end

      def take_sample
        @sample.call
      rescue StandardError
        nil
      end

      def render(snapshot)
        @sampling = false
        self.visible = !snapshot.nil?
        return unless snapshot

        @button.label = Domain::Vram.label(snapshot)
        @button.set_tooltip_text(Domain::Vram.tooltip(snapshot))
      end
    end
  end
end
