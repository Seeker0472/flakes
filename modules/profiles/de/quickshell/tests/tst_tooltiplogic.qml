import QtQuick
import QtTest
import "../shell/TooltipLogic.js" as TooltipLogic

TestCase {
    name: "TooltipLogic"

    function request(owner, target, sequence, hovered, focused, dismissed) {
        return {
            owner: owner,
            target: target,
            text: "Tooltip",
            sequence: sequence,
            hovered: hovered,
            focused: focused,
            dismissed: dismissed || false
        }
    }

    function test_pointerHoverWinsOverStaleFocus() {
        var focusedOwner = {}
        var hoveredOwner = {}
        var requests = [
            request(focusedOwner, {}, 20, false, true, false),
            request(hoveredOwner, {}, 1, true, false, false)
        ]

        verify(TooltipLogic.select(requests) === requests[1])
    }

    function test_latestPointerWins() {
        var first = request({}, {}, 3, true, false, false)
        var second = request({}, {}, 4, true, false, false)

        verify(TooltipLogic.select([first, second]) === second)
    }

    function test_focusIsFallback() {
        var first = request({}, {}, 1, false, true, false)
        var second = request({}, {}, 2, false, true, false)

        verify(TooltipLogic.select([first, second]) === second)
    }

    function test_dismissedRequestIsIgnored() {
        var dismissed = request({}, {}, 2, true, true, true)
        var available = request({}, {}, 1, false, true, false)

        verify(TooltipLogic.select([dismissed, available]) === available)
    }

    function test_unwindowedRequestIsIgnored() {
        var unwindowed = request({}, {}, 2, true, false, false)
        var available = request({}, {}, 1, false, true, false)
        unwindowed.window = null

        verify(TooltipLogic.select([unwindowed, available]) === available)
    }

    function test_dismissalClearsOnPointerReentry() {
        var target = {}
        var dismissed = request({}, target, 1, false, true, true)

        verify(TooltipLogic.dismissedAfterUpdate(dismissed, target, false, true))
        verify(!TooltipLogic.dismissedAfterUpdate(dismissed, target, true, true))
        verify(!TooltipLogic.dismissedAfterUpdate(dismissed, {}, true, true))
    }

    function test_pointerLeaveDismissesStaleFocus() {
        var target = {}
        var hovered = request({}, target, 1, true, true, false)
        var keyboardOnly = request({}, target, 2, false, true, false)

        verify(TooltipLogic.dismissedAfterUpdate(hovered, target, false, true))
        verify(!TooltipLogic.dismissedAfterUpdate(keyboardOnly, target, false, true))
        verify(!TooltipLogic.dismissedAfterUpdate(hovered, target, false, false))
    }
}
