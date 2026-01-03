# frozen_string_literal: true

module Bar
  module UI
    class PowerControlsWidget < Gtk::Box
      CONTROLS = [
        { icon: '󰌾', tooltip: 'Lock', command: %w[hyprlock], css_class: 'lock' },
        { icon: '󰍃', tooltip: 'Logout', command: %w[hyprctl dispatch exit], css_class: 'logout' },
        { icon: '⏻', tooltip: 'Power Off', command: %w[loginctl poweroff], css_class: 'power' }
      ].freeze

      def initialize
        super(:horizontal, 0)

        setup_ui
      end

      private

      def setup_ui
        CONTROLS.each do |control|
          button = create_button(control)
          pack_start(button, expand: false, fill: false, padding: 0)
        end
      end

      def create_button(control)
        button = Gtk::Button.new(label: control[:icon])
        button.style_context.add_class('pill')
        button.style_context.add_class('power-button')
        button.style_context.add_class(control[:css_class])
        button.set_tooltip_text(control[:tooltip])
        button.set_relief(:none)

        button.signal_connect('clicked') do
          execute_command(control[:command])
        end

        button
      end

      def execute_command(command)
        pid = spawn(*command, pgroup: true, [:out, :err] => '/dev/null')
        Process.detach(pid)
      end
    end
  end
end
