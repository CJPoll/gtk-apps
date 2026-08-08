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
          append(button)
        end
      end

      def create_button(control)
        button = Gtk::Button.new(label: control[:icon])
        button.add_css_class('pill')
        button.add_css_class('power-button')
        button.add_css_class(control[:css_class])
        button.set_tooltip_text(control[:tooltip])
        button.has_frame = false

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
