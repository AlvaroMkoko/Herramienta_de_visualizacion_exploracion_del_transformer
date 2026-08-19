"""Selection-contract tests for :mod:`viewmodel.transformer_bridge`."""

from viewmodel.transformer_bridge import TransformerBridge


def _record(signal):
    calls: list[tuple] = []
    signal.connect(lambda *args: calls.append(args))
    return calls


def test_select_component_opens_detail_and_emits_explicit_events():
    bridge = TransformerBridge()
    selection_changes = _record(bridge.selectionChanged)
    page_changes = _record(bridge.activePageChanged)
    clicks = _record(bridge.componentClicked)
    activations = _record(bridge.componentActivated)

    bridge.selectComponent("encoder_self_attention")

    assert bridge.selectedId == "encoder_self_attention"
    assert bridge.activePage == "detail"
    assert selection_changes == [()]
    assert page_changes == [()]
    assert clicks == [("encoder_self_attention",)]
    assert activations == [("encoder_self_attention",)]


def test_repeated_click_toggles_selection_and_returns_to_overview():
    bridge = TransformerBridge()
    cleared = _record(bridge.selectionCleared)
    clicks = _record(bridge.componentClicked)
    activations = _record(bridge.componentActivated)

    bridge.selectComponent("softmax")
    bridge.selectComponent("softmax")

    assert bridge.selectedId == ""
    assert bridge.activePage == "overview"
    assert clicks == [("softmax",), ("softmax",)]
    assert activations == [("softmax",)]
    assert cleared == [()]


def test_switching_components_keeps_detail_page_without_clearing():
    bridge = TransformerBridge()
    page_changes = _record(bridge.activePageChanged)
    cleared = _record(bridge.selectionCleared)

    bridge.selectComponent("input_embedding")
    bridge.selectComponent("linear")

    assert bridge.selectedId == "linear"
    assert bridge.activePage == "detail"
    assert page_changes == [()]
    assert cleared == []


def test_clear_selection_is_idempotent():
    bridge = TransformerBridge()
    selection_changes = _record(bridge.selectionChanged)
    page_changes = _record(bridge.activePageChanged)
    cleared = _record(bridge.selectionCleared)

    bridge.selectComponent("decoder_cross_attention")
    bridge.clearSelection()
    bridge.clearSelection()

    assert bridge.selectedId == ""
    assert bridge.activePage == "overview"
    assert len(selection_changes) == 2
    assert len(page_changes) == 2
    assert cleared == [()]


def test_show_overview_also_clears_the_selected_component():
    bridge = TransformerBridge()
    cleared = _record(bridge.selectionCleared)

    bridge.selectComponent("decoder_feed_forward")
    bridge.showOverview()

    assert bridge.selectedId == ""
    assert bridge.activePage == "overview"
    assert cleared == [()]


def test_unknown_component_does_not_change_or_emit_selection_events():
    bridge = TransformerBridge()
    clicks = _record(bridge.componentClicked)
    selection_changes = _record(bridge.selectionChanged)

    bridge.selectComponent("not_a_transformer_component")

    assert bridge.selectedId == ""
    assert bridge.activePage == "overview"
    assert clicks == []
    assert selection_changes == []
