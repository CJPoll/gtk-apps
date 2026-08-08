# frozen_string_literal: true

module Portland
  module UI
    # Bottom bar summarizing the emerge plan, with Apply and Clear actions.
    class PlanBar < Gtk::Box
      def initialize(on_apply:, on_clear:)
        super(:horizontal, 8)
        add_css_class('plan-bar')

        @summary = Gtk::Label.new('Nothing marked')
        @summary.halign = :start
        @summary.hexpand = true
        append(@summary)

        @apply = Gtk::Button.new(label: 'Apply…')
        @apply.add_css_class('suggested-action')
        @apply.signal_connect('clicked') { on_apply.call }

        @clear = Gtk::Button.new(label: 'Clear')
        @clear.signal_connect('clicked') { on_clear.call }

        append(@clear)
        append(@apply)
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
