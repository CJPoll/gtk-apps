# frozen_string_literal: true

module Portland
  module Managers
    # Runs CLI searches off the main loop and delivers parsed results back on
    # it. Results from a superseded search are dropped, so a slow early query
    # can never overwrite a newer one.
    class SearchRunner
      def initialize(on_results:)
        @on_results = on_results
        @generation = 0
      end

      def search(query)
        generation = (@generation += 1)

        Thread.new do
          output = Adapters::PortageCli.search(query)
          installed = Adapters::PortageCli.installed_atoms
          packages = Domain::SearchResultParser.parse(output, installed)

          GLib::Idle.add do
            @on_results.call(packages) if generation == @generation
            false
          end
        end
      end
    end
  end
end
