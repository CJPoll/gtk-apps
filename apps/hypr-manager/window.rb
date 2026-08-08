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
    end

    private

    def setup_ui
      root = Gtk::Box.new(:vertical, 12)
      root.add_css_class('hypr-root')

      heading = Gtk::Label.new('Drag cards to reorder displays · drag workspace chips onto a display to bind them')
      heading.halign = :start
      heading.add_css_class('heading-note')
      root.append(heading)

      @strip = Gtk::Box.new(:horizontal, 12)
      @strip.valign = :start
      strip_scroll = Gtk::ScrolledWindow.new
      strip_scroll.set_policy(:automatic, :never)
      strip_scroll.child = @strip
      strip_scroll.vexpand = true
      root.append(strip_scroll)

      @tray_holder = Gtk::Box.new(:vertical, 0)
      root.append(@tray_holder)

      root.append(build_action_bar)
      set_child(root)
    end

    def build_action_bar
      bar = Gtk::Box.new(:horizontal, 8)
      bar.add_css_class('plan-bar')

      @status = Gtk::Label.new('')
      @status.halign = :start
      @status.hexpand = true
      bar.append(@status)

      @save = Gtk::Button.new(label: 'Save & Reload')
      @save.add_css_class('suggested-action')
      @save.signal_connect('clicked') { save }

      @revert = Gtk::Button.new(label: 'Revert')
      @revert.signal_connect('clicked') { revert }

      bar.append(@revert)
      bar.append(@save)
      bar
    end

    def render
      clear_children(@strip)
      @state.layout.monitors.each do |monitor|
        card = UI::MonitorCard.new(
          monitor,
          workspace_ids: @state.assignments.workspaces_on(monitor.description),
          on_reorder: method(:reorder),
          on_mode_change: method(:change_mode),
          on_transform_change: method(:change_transform),
          on_assign: method(:assign)
        )
        @strip.append(card)
      end

      clear_children(@tray_holder)
      @tray_holder.append(UI::ChipTray.new(@state.assignments.unassigned, on_unassign: method(:unassign)))

      @status.text = @dirty ? 'Unsaved changes' : 'In sync with ~/hyprland.local.conf'
      @save.sensitive = @dirty
      @revert.sensitive = @dirty
    end

    def clear_children(box)
      box.remove(box.first_child) while box.first_child
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
