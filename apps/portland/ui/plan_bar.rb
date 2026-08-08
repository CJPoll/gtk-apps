# frozen_string_literal: true

module Portland
  module UI
    # Bottom bar summarizing the emerge plan, with Apply and Clear actions.
    class PlanBar < Gtk::Box
      def initialize(on_apply:, on_clear:)
        super(:horizontal, 8)
        style_context.add_class('plan-bar')

        @summary = Gtk::Label.new('Nothing marked')
        @summary.halign = :start
        pack_start(@summary, expand: true, fill: true, padding: 0)

        @apply = Gtk::Button.new(label: 'Apply…')
        @apply.style_context.add_class('suggested-action')
        @apply.signal_connect('clicked') { on_apply.call }

        @clear = Gtk::Button.new(label: 'Clear')
        @clear.signal_connect('clicked') { on_clear.call }

        pack_end(@apply, expand: false, fill: false, padding: 0)
        pack_end(@clear, expand: false, fill: false, padding: 0)
      end

      # Temporary state while a background step runs; the next update
      # restores normal summary and sensitivity.
      def busy(message)
        @summary.text = message
        @apply.sensitive = false
        @clear.sensitive = false
      end

      def update(plan, config_pending: false)
        parts = []
        parts << plan.summary unless plan.empty?
        parts << 'config changes pending' if config_pending
        @summary.text = parts.empty? ? 'Nothing marked' : parts.join(' · ')

        actionable = !plan.empty? || config_pending
        @apply.sensitive = actionable
        @clear.sensitive = actionable
      end
    end
  end
end
