# frozen_string_literal: true

module Bar
  module Domain
    # Pure facts about PipeWire sink node names. Identity comes from node.name,
    # never the human description: descriptions are free text ("WH-1000XM5"),
    # node names embed the device's MAC, so two bluetooth devices stay distinct.
    module AudioSink
      BLUEZ_SINK = /\Abluez_output\.(?<mac>[0-9A-Fa-f_]+)\.\d+\z/

      def self.bluetooth?(node_name)
        BLUEZ_SINK.match?(node_name.to_s)
      end

      # bluez_output.80_99_E7_F3_40_16.1 -> bluez_card.80_99_E7_F3_40_16
      def self.card_name(node_name)
        match = BLUEZ_SINK.match(node_name.to_s)
        match && "bluez_card.#{match[:mac]}"
      end
    end
  end
end
