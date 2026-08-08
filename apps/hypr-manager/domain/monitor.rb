# frozen_string_literal: true

module HyprManager
  module Domain
    # One connected display. description is the stable identity (EDID-based,
    # survives port re-enumeration — port names like DP-2 do not), name is
    # the current port. transform follows hyprland: 0 normal, 1/2/3 =
    # 90/180/270 degrees.
    Monitor = Struct.new(:name, :description, :width, :height, :refresh,
                         :x, :y, :scale, :transform, :available_modes,
                         keyword_init: true) do
      def self.from_hyprctl(data)
        new(
          name: data['name'],
          description: data['description'],
          width: data['width'],
          height: data['height'],
          refresh: data['refreshRate'],
          x: data['x'],
          y: data['y'],
          scale: data['scale'],
          transform: data['transform'],
          available_modes: data.fetch('availableModes', [])
        )
      end

      # Logical width the monitor occupies in layout coordinates: rotation
      # swaps the axes, scale shrinks them.
      def effective_width
        physical = transform.odd? ? height : width
        (physical / scale).round
      end

      def effective_height
        physical = transform.odd? ? width : height
        (physical / scale).round
      end

      def mode_string
        "#{width}x#{height}@#{format_refresh(refresh)}"
      end

      # "3840x2160@60.00Hz" (hyprctl availableModes form) -> width/height/refresh
      def apply_mode(mode)
        match = mode.match(/\A(\d+)x(\d+)@([\d.]+)/)
        return unless match

        self.width = match[1].to_i
        self.height = match[2].to_i
        self.refresh = match[3].to_f
      end

      def config_lines
        comment = "# #{description} (#{name})"
        line = "monitor = desc:#{description}, #{mode_string}, #{x}x#{y}, #{format_scale(scale)}"
        line += ", transform, #{transform}" unless transform.zero?
        [comment, line]
      end

      private

      def format_refresh(value)
        rounded = value.round(2)
        rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
      end

      def format_scale(value)
        value == value.to_i ? value.to_i.to_s : value.to_s
      end
    end
  end
end
