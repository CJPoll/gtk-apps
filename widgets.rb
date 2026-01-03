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
require_relative 'lib/widgets_window'

app = WidgetsApplication.new
app.run(ARGV)
