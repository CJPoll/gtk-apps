# frozen_string_literal: true

module HyprManager
  module UI
    # One connected display: a proportional preview, resolution and rotation
    # selectors, and the workspaces bound to it. The header is a drag handle
    # for left-right reordering; the whole card accepts drops of workspace
    # chips (bind here) and other cards (take their slot).
    class MonitorCard < Gtk::EventBox
      PREVIEW_SCALE = 14

      def initialize(monitor, workspace_ids:, on_reorder:, on_mode_change:,
                     on_transform_change:, on_assign:)
        super()
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
        box = Gtk::Box.new(:vertical, 6)
        box.style_context.add_class('monitor-card')

        box.pack_start(build_handle, expand: false, fill: false, padding: 0)
        box.pack_start(build_preview, expand: false, fill: false, padding: 0)
        box.pack_start(build_mode_combo, expand: false, fill: false, padding: 0)
        box.pack_start(build_transform_combo, expand: false, fill: false, padding: 0)
        box.pack_start(build_chips(workspace_ids), expand: false, fill: false, padding: 0)

        add(box)
      end

      def build_handle
        handle = Gtk::EventBox.new
        label = Gtk::Label.new("⣿ #{@monitor.name} — #{short_description}")
        label.ellipsize = :end
        label.style_context.add_class('monitor-handle')
        handle.add(label)

        handle.drag_source_set(Gdk::ModifierType::BUTTON1_MASK,
                               DragPayload::TARGETS, Gdk::DragAction::MOVE)
        handle.signal_connect('drag-data-get') do |_widget, _context, data, _info, _time|
          data.text = DragPayload.monitor(@monitor.description)
        end
        handle
      end

      def short_description
        @monitor.description.sub(/\ADell Inc\. /, '').strip
      end

      def build_preview
        preview = Gtk::Box.new(:vertical, 0)
        preview.style_context.add_class('screen-preview')
        preview.set_size_request(@monitor.effective_width / PREVIEW_SCALE,
                                 @monitor.effective_height / PREVIEW_SCALE)
        preview.halign = :center

        label = Gtk::Label.new(@monitor.mode_string)
        label.style_context.add_class('screen-preview-label')
        label.valign = :center
        preview.pack_start(label, expand: true, fill: true, padding: 0)
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
        row.style_context.add_class('chip-row')

        if workspace_ids.empty?
          hint = Gtk::Label.new('drop workspaces here')
          hint.style_context.add_class('chip-hint')
          row.pack_start(hint, expand: false, fill: false, padding: 0)
        else
          workspace_ids.each do |workspace_id|
            row.pack_start(WorkspaceChip.new(workspace_id), expand: false, fill: false, padding: 0)
          end
        end
        row
      end

      def setup_drop
        drag_dest_set(Gtk::DestDefaults::ALL, DragPayload::TARGETS, Gdk::DragAction::MOVE)
        signal_connect('drag-data-received') do |_widget, _context, _x, _y, data, _info, _time|
          kind, payload = DragPayload.decode(data.text.to_s)
          case kind
          when :workspace then @on_assign.call(payload, @monitor.description)
          when :monitor then @on_reorder.call(payload, @monitor.description)
          end
        end
      end
    end
  end
end
