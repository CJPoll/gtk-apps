#!/usr/bin/env ruby
# frozen_string_literal: true

require 'gtk3'
require 'gobject-introspection'

# Load gtk-layer-shell via GObject Introspection
module GtkLayerShell
  class Loader < GObjectIntrospection::Loader
  end

  loader = Loader.new(self)
  loader.load('GtkLayerShell')
end

require_relative 'lib/widgets_application'
require_relative 'lib/compositor/adapters/hyprland_ipc'
require_relative 'lib/compositor/domain/workspace'
require_relative 'lib/bar/domain/launcher'
require_relative 'lib/bar/ui/clock_widget'
require_relative 'lib/bar/ui/memory_widget'
require_relative 'lib/bar/ui/cpu_widget'
require_relative 'lib/bar/ui/battery_widget'
require_relative 'lib/bar/ui/brightness_widget'
require_relative 'lib/bar/ui/workspaces_widget'
require_relative 'lib/bar/ui/launcher_button'
require_relative 'lib/bar/ui/launchers_widget'
require_relative 'lib/bar/ui/volume_widget'
require_relative 'lib/bar/ui/audio_sink_widget'
require_relative 'lib/bar/ui/network_widget'
require_relative 'lib/bar/ui/power_controls_widget'
require_relative 'lib/widgets_window'

app = WidgetsApplication.new
app.run(ARGV)
