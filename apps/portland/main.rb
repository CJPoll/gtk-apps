# frozen_string_literal: true

require 'gtk3'
require 'zeitwerk'

module Portland; end

loader = Zeitwerk::Loader.new
loader.inflector.inflect('ui' => 'UI')
loader.push_dir(File.expand_path('../../lib', __dir__))
loader.push_dir(__dir__, namespace: Portland)
loader.ignore(__FILE__)
loader.setup

# Not a layer-shell client: portland is an ordinary tiled window.

Portland::Application.new.run(ARGV)
