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

require_relative 'lib/launcher/domain/app_entry'
require_relative 'lib/launcher/ui/dock_icon'
require_relative 'lib/launcher/ui/dock'
require_relative 'lib/launcher_application'
require_relative 'lib/launcher_window'

app = LauncherApplication.new
app.run(ARGV)
