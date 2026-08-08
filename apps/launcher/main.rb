# frozen_string_literal: true

require 'gtk3'
require 'zeitwerk'

module Launcher; end

loader = Zeitwerk::Loader.new
loader.inflector.inflect('ui' => 'UI')
loader.push_dir(File.expand_path('../../lib', __dir__))
loader.push_dir(__dir__, namespace: Launcher)
loader.ignore(__FILE__)
loader.setup

GtkKit::LayerShell.load!

Launcher::Application.new.run(ARGV)
