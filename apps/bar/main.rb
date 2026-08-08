# frozen_string_literal: true

require 'gtk4'
require 'zeitwerk'

module Bar; end

loader = Zeitwerk::Loader.new
loader.inflector.inflect('ui' => 'UI')
loader.push_dir(File.expand_path('../../lib', __dir__))
loader.push_dir(__dir__, namespace: Bar)
loader.ignore(__FILE__)
loader.setup

GtkKit::LayerShell.load!

Bar::Application.new.run(ARGV)
