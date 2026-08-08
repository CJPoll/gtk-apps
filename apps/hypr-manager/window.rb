# frozen_string_literal: true

module HyprManager
  class Window < Gtk::Window
    def initialize(application:)
      super()
      set_application(application)
      set_title('Hypr Manager')
      set_default_size(980, 520)

      @store = Managers::ConfigStore.new
      @state = @store.load
      @dirty = false

      setup_ui
      render
      show_all
    end

    private

    def setup_ui
      root = Gtk::Box.new(:vertical, 12)
      root.style_context.add_class('hypr-root')

      heading = Gtk::Label.new('Drag cards to reorder displays · drag workspace chips onto a display to bind them')
      heading.halign = :start
      heading.style_context.add_class('heading-note')
      root.pack_start(heading, expand: false, fill: false, padding: 0)

      @strip = Gtk::Box.new(:horizontal, 12)
      @strip.valign = :start
      strip_scroll = Gtk::ScrolledWindow.new
      strip_scroll.set_policy(:automatic, :never)
      strip_scroll.add(@strip)
      root.pack_start(strip_scroll, expand: true, fill: true, padding: 0)

      @tray_holder = Gtk::Box.new(:vertical, 0)
      root.pack_start(@tray_holder, expand: false, fill: false, padding: 0)

      root.pack_end(build_action_bar, expand: false, fill: false, padding: 0)
      add(root)
    end

    def build_action_bar
      bar = Gtk::Box.new(:horizontal, 8)
      bar.style_context.add_class('plan-bar')

      @status = Gtk::Label.new('')
      @status.halign = :start
      bar.pack_start(@status, expand: true, fill: true, padding: 0)

      @save = Gtk::Button.new(label: 'Save & Reload')
      @save.style_context.add_class('suggested-action')
      @save.signal_connect('clicked') { save }

      @revert = Gtk::Button.new(label: 'Revert')
      @revert.signal_connect('clicked') { revert }

      bar.pack_end(@save, expand: false, fill: false, padding: 0)
      bar.pack_end(@revert, expand: false, fill: false, padding: 0)
      bar
    end

    def render
      @strip.children.each(&:destroy)
      @state.layout.monitors.each do |monitor|
        card = UI::MonitorCard.new(
          monitor,
          workspace_ids: @state.assignments.workspaces_on(monitor.description),
          on_reorder: method(:reorder),
          on_mode_change: method(:change_mode),
          on_transform_change: method(:change_transform),
          on_assign: method(:assign)
        )
        @strip.pack_start(card, expand: false, fill: false, padding: 0)
      end

      @tray_holder.children.each(&:destroy)
      @tray_holder.add(UI::ChipTray.new(@state.assignments.unassigned, on_unassign: method(:unassign)))

      @status.text = @dirty ? 'Unsaved changes' : 'In sync with ~/hyprland.local.conf'
      @save.sensitive = @dirty
      @revert.sensitive = @dirty
      @strip.show_all
      @tray_holder.show_all
    end

    def mutated
      @dirty = true
      render
    end

    def reorder(description, before_description)
      @state.layout.reorder(description, before_description)
      mutated
    end

    def change_mode(description, mode)
      return if mode.nil? || @state.layout.find(description)&.mode_string == mode[/\A\d+x\d+@[\d.]+/]

      @state.layout.set_mode(description, mode)
      mutated
    end

    def change_transform(description, transform)
      return if @state.layout.find(description)&.transform == transform

      @state.layout.set_transform(description, transform)
      mutated
    end

    def assign(workspace_id, description)
      @state.assignments.assign(workspace_id, description)
      mutated
    end

    def unassign(workspace_id)
      @state.assignments.unassign(workspace_id)
      mutated
    end

    def save
      @store.save(@state)
      @dirty = false
      render
      @status.text = 'Saved and reloaded hyprland'
    end

    def revert
      @state = @store.load
      @dirty = false
      render
    end
  end
end
