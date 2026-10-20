# frozen_string_literal: true

require 'gtk4'
require 'zeitwerk'

module HyprManager; end

loader = Zeitwerk::Loader.new
loader.inflector.inflect('ui' => 'UI')
loader.push_dir(File.expand_path('../../lib', __dir__))
loader.push_dir(__dir__, namespace: HyprManager)
loader.ignore(__FILE__)
loader.setup

# The main window is an ordinary tiled window; layer-shell is loaded only for
# the Identify-screen overlays (bin/hypr-manager preloads libgtk4-layer-shell).
begin
  GtkKit::LayerShell.load!
rescue StandardError => e
  # Without the typelib the manager still works; Identify reports itself unsupported.
  warn "layer-shell unavailable, Identify screen disabled: #{e.message}"
end

HyprManager::Application.new.run(ARGV)
