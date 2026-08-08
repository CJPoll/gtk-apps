# frozen_string_literal: true

module HyprManager
  module UI
    # One connected display: a proportional preview, resolution and rotation
    # selectors, and the workspaces bound to it. The header is a drag handle
    # for left-right reordering; the whole card accepts drops of workspace
    # chips (bind here) and other cards (take their slot).
    class MonitorCard < Gtk::Box
      PREVIEW_SCALE = 14

      def initialize(monitor, workspace_ids:, on_reorder:, on_mode_change:,
                     on_transform_change:, on_assign:)
        super(:vertical, 6)
        @monitor = monitor
        @on_reorder = on_reorder
        @on_mode_change = on_mode_change
        @on_transform_change = on_transform_change
        @on_assign = on_assign

        build(workspace_ids)
        setup_drop
      end

      private

      def build(workspace_ids)
        add_css_class('monitor-card')

        append(build_handle)
        append(build_preview)
        append(build_mode_combo)
        append(build_transform_combo)
        append(build_chips(workspace_ids))
      end

      def build_handle
        label = Gtk::Label.new("⣿ #{@monitor.name} — #{short_description}")
        label.ellipsize = :end
        label.add_css_class('monitor-handle')

        source = Gtk::DragSource.new
        source.actions = :move
        source.signal_connect('prepare') do |_source, _x, _y|
          Gdk::ContentProvider.new(DragPayload.monitor(@monitor.description))
        end
        label.add_controller(source)
        label
      end

      def short_description
        @monitor.description.sub(/\ADell Inc\. /, '').strip
      end

      def build_preview
        preview = Gtk::Box.new(:vertical, 0)
        preview.add_css_class('screen-preview')
        preview.set_size_request(@monitor.effective_width / PREVIEW_SCALE,
                                 @monitor.effective_height / PREVIEW_SCALE)
        preview.halign = :center

        label = Gtk::Label.new(@monitor.mode_string)
        label.add_css_class('screen-preview-label')
        label.valign = :center
        label.vexpand = true
        preview.append(label)
        preview
      end

      def build_mode_combo
        combo = Gtk::ComboBoxText.new
        modes = @monitor.available_modes
        modes = [@monitor.mode_string] if modes.empty?
        modes.each { |mode| combo.append_text(mode) }

        current = modes.index { |mode| mode.start_with?("#{@monitor.width}x#{@monitor.height}@") &&
                                       mode[/@([\d.]+)/, 1].to_f.round == @monitor.refresh.round }
        combo.active = current || 0

        combo.signal_connect('changed') do
          @on_mode_change.call(@monitor.description, combo.active_text)
        end
        combo
      end

      def build_transform_combo
        combo = Gtk::ComboBoxText.new
        { '0' => 'Normal', '1' => 'Rotated 90°', '2' => 'Rotated 180°', '3' => 'Rotated 270°' }
          .each { |id, text| combo.append(id, text) }
        combo.active_id = @monitor.transform.to_s

        combo.signal_connect('changed') do
          @on_transform_change.call(@monitor.description, combo.active_id.to_i)
        end
        combo
      end

      def build_chips(workspace_ids)
        row = Gtk::Box.new(:horizontal, 4)
        row.add_css_class('chip-row')

        if workspace_ids.empty?
          hint = Gtk::Label.new('drop workspaces here')
          hint.add_css_class('chip-hint')
          row.append(hint)
        else
          workspace_ids.each do |workspace_id|
            row.append(WorkspaceChip.new(workspace_id))
          end
        end
        row
      end

      def setup_drop
        target = Gtk::DropTarget.new(DragPayload::STRING_TYPE, :move)
        target.signal_connect('drop') do |_target, value, _x, _y|
          kind, payload = DragPayload.decode_drop(value)
          case kind
          when :workspace then @on_assign.call(payload, @monitor.description)
          when :monitor then @on_reorder.call(payload, @monitor.description)
          end
          !kind.nil?
        end
        add_controller(target)
      end
    end
  end
end
