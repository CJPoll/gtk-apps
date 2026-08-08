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

      def update(plan)
        @summary.text = plan.summary
        @apply.sensitive = !plan.empty?
        @clear.sensitive = !plan.empty?
      end
    end
  end
end
