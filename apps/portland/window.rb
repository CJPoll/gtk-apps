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
      @detail_fetcher = Managers::DetailFetcher.new
      @resolver = Managers::DependencyResolver.new
      @overrides = load_overrides
      @packages = []

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
      update_plan_bar
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
      sync_button.signal_connect('clicked') do
        Adapters::Terminal.run('sudo -A emerge --sync') { refresh_current_view }
      end

      world_button = Gtk::Button.new(label: 'World')
      world_button.tooltip_text = 'List deliberately installed packages (the world set) — dependencies excluded'
      world_button.signal_connect('clicked') { show_world }

      updates_button = Gtk::Button.new(label: 'Updates')
      updates_button.tooltip_text = 'List installed packages with a newer version visible under your keywords'
      updates_button.signal_connect('clicked') { scan_updates }

      @upgrade_all = Gtk::ToggleButton.new(label: 'Upgrade All')
      @upgrade_all.tooltip_text = 'Mark a full world update (emerge --update --deep --newuse @world) in the plan'
      @upgrade_all.signal_connect('toggled') do
        next if @syncing_upgrade_all

        @plan.toggle_world_update
        update_plan_bar
      end

      bar.pack_start(@search_entry, expand: true, fill: true, padding: 0)
      bar.pack_end(sync_button, expand: false, fill: false, padding: 0)
      bar.pack_end(world_button, expand: false, fill: false, padding: 0)
      bar.pack_end(@upgrade_all, expand: false, fill: false, padding: 0)
      bar.pack_end(updates_button, expand: false, fill: false, padding: 0)
      bar
    end

    def build_results
      @results_list = Gtk::ListBox.new
      @results_list.selection_mode = :none

      @placeholder = Gtk::Label.new('Search for packages to get started')
      @placeholder.style_context.add_class('results-placeholder')
      @placeholder.show
      @results_list.set_placeholder(@placeholder)

      scrolled = Gtk::ScrolledWindow.new
      scrolled.set_policy(:never, :automatic)
      scrolled.add(@results_list)
      scrolled
    end

    def run_search
      query = @search_entry.text.strip
      return if query.empty?

      @current_view = [:search, query]
      @search_runner.search(query)
    end

    def show_world
      @current_view = [:world]
      @search_runner.list_world
    end

    def scan_updates
      @current_view = [:updates]
      @results_list.children.each(&:destroy)
      @placeholder.text = 'Scanning installed packages for available updates…'
      @search_runner.list_updates
    end

    # After an emerge finishes (or a sync), installed state, versions, and
    # update availability have all potentially changed; re-run whatever
    # listing is on screen against the new reality.
    def refresh_current_view
      @detail_fetcher.invalidate!

      case @current_view&.first
      when :search then @search_runner.search(@current_view[1])
      when :world then @search_runner.list_world
      when :updates then scan_updates
      end
    end

    def render_results(packages)
      @placeholder.text = packages.empty? ? 'Nothing found' : 'Search for packages to get started'
      @packages = packages
      @results_list.children.each(&:destroy)

      packages.each do |package|
        row = UI::PackageRow.new(
          package,
          detail_fetcher: @detail_fetcher,
          marked_lookup: ->(atom) { @plan.action_for(atom) },
          use_staged_lookup: ->(atom, flag) { @overrides.use_for(atom)[flag] },
          keyword_staged_lookup: ->(atom) { @overrides.keyword_for(atom) },
          on_toggle: method(:toggle_mark),
          on_use_toggle: method(:stage_use_change),
          on_keyword_toggle: method(:stage_keyword_change)
        )
        @results_list.add(row)
      end

      @results_list.show_all
    end

    def load_overrides
      Domain::Overrides.new(
        use_content: Adapters::PortageCli.portland_use_content,
        keywords_content: Adapters::PortageCli.portland_keywords_content,
        stable_unmask_content: Adapters::PortageCli.portland_stable_unmask_content
      )
    end

    def update_plan_bar
      @plan_bar.update(@plan, config_pending: @overrides.dirty?)
      # Clear/revert reset the plan; keep the toggle honest without
      # re-firing its handler.
      @syncing_upgrade_all = true
      @upgrade_all.active = @plan.world_update?
      @syncing_upgrade_all = false
    end

    def toggle_mark(atom, action)
      @plan.toggle(atom, action)
      update_plan_bar
    end

    def stage_use_change(atom, flag, value)
      @overrides.set_use(atom, flag, value)
      update_plan_bar
    end

    def stage_keyword_change(atom, keyword)
      @overrides.set_keyword(atom, keyword)
      update_plan_bar
    end

    # Installs resolve against a sandbox first (staged config included), so
    # dependency keyword/USE/mask requirements surface as a prompt here
    # instead of a failed emerge in the terminal.
    def apply_plan
      resolvable = @plan.installs + @plan.upgrades
      if resolvable.empty? && !@plan.world_update?
        install_config_then_emerge
        return
      end

      @plan_bar.busy(@plan.world_update? ? 'Resolving world update…' : 'Resolving dependencies…')
      @resolver.resolve(resolvable, @overrides, world_update: @plan.world_update?,
                        on_progress: ->(message) { @plan_bar.busy(message) }) do |result|
        update_plan_bar
        handle_resolution(result)
      end
    end

    def handle_resolution(result)
      unless result.anything?
        if result.error
          show_resolution_error(result.error)
        else
          install_config_then_emerge
        end
        return
      end

      accepted = UI::DependencyChangesDialog.new(parent: self, result: result).run_and_select
      return unless accepted

      accepted[:changes].each { |change| stage_suggested(change) }
      accepted[:unmask_flags].each { |flag| @overrides.set_stable_unmask(flag) }
      accepted[:extra_atoms].each do |atom|
        @plan.toggle(atom, :upgrade) unless @plan.action_for(atom)
      end
      update_plan_bar
      install_config_then_emerge
    end

    def stage_suggested(change)
      if change.kind == :keyword
        @overrides.set_keyword(change.atom_spec, change.tokens.first)
      else
        change.tokens.each do |token|
          @overrides.set_use(change.atom_spec, token.delete_prefix('-'), !token.start_with?('-'))
        end
      end
    end

    def show_resolution_error(error)
      dialog = Gtk::MessageDialog.new(parent: self, flags: :modal, type: :error,
                                      buttons: :close,
                                      message: 'emerge cannot resolve this install')
      dialog.secondary_text = error
      dialog.run
      dialog.destroy
    end

    # Config installs first (headless sudo — the askpass dialog appears);
    # emerges follow in a terminal only once that succeeds, so a cancelled
    # password never leaves emerge running against stale config.
    def install_config_then_emerge
      unless @overrides.dirty?
        run_emerges
        return
      end

      stable_unmask = @overrides.stable_unmasks.any? ? @overrides.render_stable_unmask : nil
      Adapters::ConfigInstaller.install(@overrides.render_use, @overrides.render_keywords,
                                        stable_unmask_content: stable_unmask) do |success|
        if success
          @overrides.saved!
          @detail_fetcher.invalidate!
          update_plan_bar
          run_emerges
        else
          warn 'portland: config install failed or was cancelled; emerge not started'
        end
      end
    end

    def run_emerges
      commands = @plan.shell_commands
      return if commands.empty?

      Adapters::Terminal.run(commands.join(' && ')) { refresh_current_view }
    end

    def clear_plan
      @plan.clear
      @overrides = load_overrides
      update_plan_bar
      render_results(@packages)
    end
  end
end
