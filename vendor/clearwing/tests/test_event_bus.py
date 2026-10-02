"""EventBus coverage for delivery ordering, late-subscriber semantics, and
exception resilience when a subscriber callback fails mid-emit.

Fallout from the dd5f093 audit — the existing `test_events.py` covers basic
subscribe/emit, singleton, handler isolation, and thread safety, but leaves
the following behaviors (load-bearing for the TUI / `/ws/agent` streams) un-
pinned:

  1. Events are delivered to subscribers in the order they were emitted.
  2. A subscriber that joins *after* events have been emitted does NOT
     receive backfilled history — the bus is fire-and-forget, not a log.
  3. If one subscriber raises (e.g. a WebSocket that disconnected between
     emits), emission must not crash and other subscribers must still fire.

These tests only exercise public API; the singleton is reset between tests
so the suite is independent of prior state.
"""

from __future__ import annotations

from clearwing.core.events import EventBus, EventType


def _reset_bus() -> None:
    """Drop the process-wide EventBus singleton for test isolation."""
    EventBus._instance = None


class TestEventOrdering:
    def setup_method(self) -> None:
        _reset_bus()

    def teardown_method(self) -> None:
        _reset_bus()

    def test_events_delivered_in_emission_order(self) -> None:
        """A single subscriber must see events in the order emit() was called.

        Progress streams (HUNT_PROGRESS, SOURCEHUNT_STAGE, etc.) rely on this:
        the web UI renders stages as they arrive and out-of-order delivery
        would show a later stage before an earlier one.
        """
        bus = EventBus()
        received: list[int] = []
        bus.subscribe(EventType.HUNT_PROGRESS, lambda data: received.append(data))

        for i in range(50):
            bus.emit(EventType.HUNT_PROGRESS, i)

        assert received == list(range(50))

    def test_ordering_preserved_across_multiple_subscribers(self) -> None:
        """Each subscriber independently sees the full stream in order."""
        bus = EventBus()
        a: list[int] = []
        b: list[int] = []
        bus.subscribe(EventType.MESSAGE, lambda data: a.append(data))
        bus.subscribe(EventType.MESSAGE, lambda data: b.append(data))

        for i in range(10):
            bus.emit(EventType.MESSAGE, i)

        assert a == list(range(10))
        assert b == list(range(10))


class TestLateSubscriber:
    def setup_method(self) -> None:
        _reset_bus()

    def teardown_method(self) -> None:
        _reset_bus()

    def test_late_subscriber_does_not_receive_backfilled_events(self) -> None:
        """A subscriber that joins after emission sees nothing from the past.

        This pins down the design: EventBus is a live pub/sub, not a replay
        log. The `/ws/agent` endpoint opens subscriptions when a client
        connects; anything emitted before connection is intentionally lost.
        """
        bus = EventBus()

        # Emit three events with no subscriber attached.
        bus.emit(EventType.MESSAGE, "pre-1")
        bus.emit(EventType.MESSAGE, "pre-2")
        bus.emit(EventType.MESSAGE, "pre-3")

        # Subscribe *after* the fact.
        received: list[str] = []
        bus.subscribe(EventType.MESSAGE, lambda data: received.append(data))

        # No backfill.
        assert received == []

        # And a fresh emit reaches the late subscriber normally.
        bus.emit(EventType.MESSAGE, "post-1")
        assert received == ["post-1"]

    def test_late_subscriber_only_sees_events_of_its_own_type(self) -> None:
        """Late subscribers don't get backfill *and* are scoped by type."""
        bus = EventBus()
        bus.emit(EventType.MESSAGE, "old-msg")
        bus.emit(EventType.ERROR, "old-err")

        msgs: list[str] = []
        bus.subscribe(EventType.MESSAGE, lambda data: msgs.append(data))

        bus.emit(EventType.ERROR, "new-err")  # wrong type for this subscriber
        bus.emit(EventType.MESSAGE, "new-msg")

        assert msgs == ["new-msg"]


class TestSubscriberExceptionResilience:
    """If one subscriber raises mid-emit (e.g. a disconnected WebSocket
    whose send() threw), the bus must swallow the error, continue dispatch
    to remaining subscribers, and not propagate the exception to the emitter.
    """

    def setup_method(self) -> None:
        _reset_bus()

    def teardown_method(self) -> None:
        _reset_bus()

    def test_exception_in_subscriber_does_not_crash_emitter(self) -> None:
        bus = EventBus()

        def raising_handler(data: object) -> None:
            raise ConnectionResetError("simulated WebSocket disconnect")

        bus.subscribe(EventType.HUNT_PROGRESS, raising_handler)

        # Must not raise.
        bus.emit(EventType.HUNT_PROGRESS, {"stage": "scan"})

    def test_subsequent_subscribers_still_receive_event_after_raise(self) -> None:
        """Bad subscriber registered first must not starve later ones."""
        bus = EventBus()
        received: list[object] = []

        def raising_handler(data: object) -> None:
            raise ConnectionResetError("simulated WebSocket disconnect")

        def good_handler(data: object) -> None:
            received.append(data)

        # Order matters: bad handler is called first.
        bus.subscribe(EventType.SOURCEHUNT_STAGE, raising_handler)
        bus.subscribe(EventType.SOURCEHUNT_STAGE, good_handler)

        bus.emit(EventType.SOURCEHUNT_STAGE, {"stage": "hunt", "status": "running"})

        assert received == [{"stage": "hunt", "status": "running"}]

    def test_multiple_raising_subscribers_all_isolated(self) -> None:
        """A whole cohort of dead WebSockets must not block the live one."""
        bus = EventBus()
        received: list[object] = []

        def raiser_a(data: object) -> None:
            raise RuntimeError("a")

        def raiser_b(data: object) -> None:
            raise ValueError("b")

        def raiser_c(data: object) -> None:
            raise ConnectionResetError("c")

        def survivor(data: object) -> None:
            received.append(data)

        bus.subscribe(EventType.MESSAGE, raiser_a)
        bus.subscribe(EventType.MESSAGE, raiser_b)
        bus.subscribe(EventType.MESSAGE, raiser_c)
        bus.subscribe(EventType.MESSAGE, survivor)

        bus.emit(EventType.MESSAGE, "payload")

        assert received == ["payload"]

    def test_emit_order_preserved_when_middle_subscriber_raises(self) -> None:
        """Ordering guarantee holds even when a mid-chain subscriber errors."""
        bus = EventBus()
        received: list[int] = []

        def early(data: int) -> None:
            received.append(data * 10)

        def boom(data: int) -> None:
            raise RuntimeError("dead ws")

        def late(data: int) -> None:
            received.append(data)

        bus.subscribe(EventType.HUNT_PROGRESS, early)
        bus.subscribe(EventType.HUNT_PROGRESS, boom)
        bus.subscribe(EventType.HUNT_PROGRESS, late)

        for i in (1, 2, 3):
            bus.emit(EventType.HUNT_PROGRESS, i)

        # For each emit: early appends i*10, boom raises (swallowed), late
        # appends i. So we expect [10, 1, 20, 2, 30, 3].
        assert received == [10, 1, 20, 2, 30, 3]
