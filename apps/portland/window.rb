# frozen_string_literal: true

module Portland
  class Window < Gtk::Window
    def initialize(application:)
      super()
      set_application(application)
      set_title('Portland')
      set_default_size(900, 600)

      @plan = Domain::EmergePlan.new
      @search_runner = Managers::SearchRunner.new(on_results: method(:render_results))
      @slot_fetcher = Managers::SlotFetcher.new

      setup_ui
      show_all
    end

    private

    def setup_ui
      root = Gtk::Box.new(:vertical, 8)
      root.style_context.add_class('portland-root')

      root.pack_start(build_top_bar, expand: false, fill: false, padding: 0)
      root.pack_start(build_results, expand: true, fill: true, padding: 0)

      @plan_bar = UI::PlanBar.new(
        on_apply: -> { apply_plan },
        on_clear: -> { clear_plan }
      )
      @plan_bar.update(@plan)
      root.pack_end(@plan_bar, expand: false, fill: false, padding: 0)

      add(root)
    end

    def build_top_bar
      bar = Gtk::Box.new(:horizontal, 8)

      @search_entry = Gtk::SearchEntry.new
      @search_entry.placeholder_text = 'Search packages — Enter to search'
      @search_entry.signal_connect('activate') { run_search }

      sync_button = Gtk::Button.new(label: '⟳ Sync')
      sync_button.tooltip_text = 'Run sudo emerge --sync in a terminal'
      sync_button.signal_connect('clicked') { Adapters::Terminal.run('sudo -A emerge --sync') }

      bar.pack_start(@search_entry, expand: true, fill: true, padding: 0)
      bar.pack_end(sync_button, expand: false, fill: false, padding: 0)
      bar
    end

    def build_results
      @results_list = Gtk::ListBox.new
      @results_list.selection_mode = :none

      placeholder = Gtk::Label.new('Search for packages to get started')
      placeholder.style_context.add_class('results-placeholder')
      placeholder.show
      @results_list.set_placeholder(placeholder)

      scrolled = Gtk::ScrolledWindow.new
      scrolled.set_policy(:never, :automatic)
      scrolled.add(@results_list)
      scrolled
    end

    def run_search
      query = @search_entry.text.strip
      return if query.empty?

      @search_runner.search(query)
    end

    def render_results(packages)
      @results_list.children.each(&:destroy)

      packages.each do |package|
        row = UI::PackageRow.new(
          package,
          slot_fetcher: @slot_fetcher,
          marked_lookup: ->(atom) { @plan.action_for(atom) },
          on_toggle: method(:toggle_mark)
        )
        @results_list.add(row)
      end

      @results_list.show_all
    end

    def toggle_mark(atom, action)
      @plan.toggle(atom, action)
      @plan_bar.update(@plan)
    end

    def apply_plan
      commands = @plan.shell_commands
      return if commands.empty?

      Adapters::Terminal.run(commands.join(' && '))
    end

    def clear_plan
      @plan.clear
      @plan_bar.update(@plan)
      @results_list.children.each do |row|
        row.reset! if row.respond_to?(:reset!)
      end
    end
  end
end
