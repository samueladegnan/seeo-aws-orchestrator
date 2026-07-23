"""Background service that monitors environment TTLs and tears them down."""

import threading
import time
import traceback
from typing import Callable

from ..config import get_settings
from .aws_service import AWSService


class TTLService:
    """Runs a background thread that terminates expired environments."""

    def __init__(self, aws_service: AWSService, interval_seconds: int | None = None):
        self.aws_service = aws_service
        self.interval_seconds = interval_seconds or get_settings().ttl_check_interval_seconds
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()

    def start(self) -> None:
        """Start the background TTL monitor."""
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        """Signal the background monitor to stop."""
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=5.0)

    def _run(self) -> None:
        """Loop until stopped, terminating expired environments."""
        while not self._stop_event.is_set():
            try:
                expired = self.aws_service.list_expired_environments()
                for env in expired:
                    print(f"[TTL] Environment {env.id} expired; terminating...")
                    self.aws_service.terminate_environment(env.id)
            except Exception:  # noqa: BLE001
                # Log and continue; don't crash the background thread
                print("[TTL] Error during TTL scan:")
                traceback.print_exc()

            time.sleep(self.interval_seconds)
