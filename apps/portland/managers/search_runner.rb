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
        deliver do
          output = Adapters::PortageCli.search(query)
          installed = Adapters::PortageCli.installed_atoms
          Domain::SearchResultParser.parse(output, installed)
        end
      end

      # The world set: packages deliberately emerged, dependencies excluded.
      def list_world
        deliver do
          specs = Adapters::PortageCli.world_specs
          atoms = specs.map { |spec| spec.strip.split(':', 2).first }
          descriptions = atoms.to_h { |atom| [atom, Adapters::PortageCli.installed_description(atom)] }
          Domain::WorldList.build(specs, descriptions: descriptions)
        end
      end

      # Every installed package with a newer version visible under the
      # current keyword config. A few seconds of metadata-cache reads.
      def list_updates
        deliver do
          arch = Adapters::PortageCli.arch
          keyword_entries = Adapters::PortageCli.keyword_config_entries

          Adapters::PortageCli.all_installed_slot_versions.filter_map do |atom, slots|
            updates = Domain::UpdateScan.updates_for(
              atom, Adapters::PortageCli.slot_entries(atom), slots,
              arch: arch, keyword_entries: keyword_entries
            )
            next if updates.empty?

            Domain::Package.new(
              atom: atom,
              description: Adapters::PortageCli.installed_description(atom) || '',
              installed: true,
              note: updates.map { |u| "#{u[:from]} → #{u[:to]}" }.join(' · ')
            )
          end.sort_by(&:atom)
        end
      end

      private

      def deliver(&block)
        generation = (@generation += 1)

        Thread.new do
          packages = block.call

          GLib::Idle.add do
            @on_results.call(packages) if generation == @generation
            false
          end
        end
      end
    end
  end
end
