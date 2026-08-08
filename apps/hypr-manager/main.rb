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

# Not a layer-shell client: hypr-manager is an ordinary tiled window.

HyprManager::Application.new.run(ARGV)
