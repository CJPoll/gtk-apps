# frozen_string_literal: true

require 'minitest/autorun'
require 'zeitwerk'

# Domain tests need no GTK: Zeitwerk autoloads only the constants a test
# references, so GTK-dependent UI classes are never loaded here.
module Portland; end

loader = Zeitwerk::Loader.new
loader.inflector.inflect('ui' => 'UI')
loader.push_dir(File.expand_path('../apps/portland', __dir__), namespace: Portland)
loader.setup
