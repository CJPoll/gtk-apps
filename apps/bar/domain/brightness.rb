# frozen_string_literal: true

module Bar
  module Domain
    # Pure conversions between the backlight's raw sysfs scale (0..max_raw,
    # panel-specific — 62194 on this machine) and the 1..100 percent scale the
    # UI presents.
    module Brightness
      # Sliding to a true zero blanks the panel with no on-screen way back, so
      # the usable range bottoms out just above it.
      MIN_PERCENT = 1
      MAX_PERCENT = 100

      def self.to_percent(raw, max_raw)
        return MIN_PERCENT if max_raw.to_i <= 0

        clamp((raw.to_f / max_raw * 100).round)
      end

      def self.to_raw(percent, max_raw)
        return 0 if max_raw.to_i <= 0

        (clamp(percent) / 100.0 * max_raw).round
      end

      def self.clamp(percent)
        percent.to_i.clamp(MIN_PERCENT, MAX_PERCENT)
      end

      # Scroll wheels encode direction in the delta's sign, scrolling up (a
      # negative delta) meaning brighter. Kinetic and stop events report a zero
      # delta: that is "no movement", not a direction, and stepping on it dims
      # the panel without the user asking.
      def self.scroll_step(delta_y, step)
        return 0 if delta_y.zero?

        delta_y.negative? ? step : -step
      end

      def self.icon(percent)
        case percent
        when 75.. then '󰃠'
        when 50...75 then '󰃟'
        when 25...50 then '󰃞'
        else '󰃝'
        end
      end

      def self.label(percent)
        "#{icon(percent)} #{percent}%"
      end
    end
  end
end
