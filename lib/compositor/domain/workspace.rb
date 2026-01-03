# frozen_string_literal: true

module Compositor
  module Domain
    Workspace = Struct.new(
      :id,
      :name,
      :monitor,
      :monitor_id,
      :windows,
      :active,
      :urgent,
      keyword_init: true
    ) do
      # Display name mapping (matches waybar config)
      DISPLAY_NAMES = {
        1 => '1',
        2 => '2',
        3 => '3',
        4 => '4',
        5 => 'GAMES',
        6 => 'MEDIA'
      }.freeze

      def display_name
        DISPLAY_NAMES[id] || name || id.to_s
      end

      def self.from_hyprland(json, active_id: nil)
        new(
          id: json['id'],
          name: json['name'],
          monitor: json['monitor'],
          monitor_id: json['monitorID'],
          windows: json['windows'],
          active: json['id'] == active_id,
          urgent: false # Hyprland doesn't expose urgent in workspace query
        )
      end
    end
  end
end
