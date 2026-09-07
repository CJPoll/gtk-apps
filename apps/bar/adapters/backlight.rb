# frozen_string_literal: true

module Bar
  module Adapters
    # Reads and writes the panel backlight through /sys/class/backlight.
    #
    # No sudo and no helper binary: the brightness file is group-writable by
    # `video`, which the desktop user belongs to. Returns plain integers on the
    # raw panel scale; percent conversion belongs to Domain::Brightness.
    class Backlight
      SYSFS_ROOT = '/sys/class/backlight'

      class << self
        # nil on desktops with no backlight at all — callers hide the widget.
        def detect
          path = Dir.glob(File.join(SYSFS_ROOT, '*')).sort.first
          return nil unless path

          max_raw = read_int(File.join(path, 'max_brightness'))
          return nil unless max_raw&.positive?

          new(path, max_raw)
        end

        def read_int(path)
          value = File.read(path).strip
          Integer(value, 10)
        rescue ArgumentError, SystemCallError, IOError
          nil
        end
      end

      attr_reader :max_raw

      def initialize(path, max_raw)
        @path = path
        @max_raw = max_raw
      end

      # `brightness` holds the last *requested* level, and reads 0 until
      # something writes it — on a fresh boot that is nobody, so fall back to
      # the hardware's own reading. Once the slider has written a value
      # (never 0, see Domain::Brightness::MIN_PERCENT) the request wins, which
      # keeps the pill steady while adaptive backlight nudges the actual level.
      def raw
        requested = self.class.read_int(File.join(@path, 'brightness'))
        return requested if requested&.positive?

        self.class.read_int(File.join(@path, 'actual_brightness'))
      end

      def raw=(value)
        File.write(File.join(@path, 'brightness'), value.to_i.to_s)
      rescue SystemCallError, IOError => e
        warn "Backlight: cannot set brightness (#{e.message})"
      end
    end
  end
end
