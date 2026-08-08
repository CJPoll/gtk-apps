# frozen_string_literal: true

# Shared GTK plumbing for every app in this repo: application shell,
# stylesheet stack, GLib timer helpers, and the layer-shell bootstrap.
module GtkKit
  # Repository root in development; the mirrored tree root when deployed.
  def self.root
    @root ||= File.expand_path('..', __dir__)
  end
end
