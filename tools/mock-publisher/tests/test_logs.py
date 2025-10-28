import argparse
import importlib.util
import json
import threading
import time
import types
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBLISHER_PATH = ROOT / "tools" / "mock-publisher" / "publisher.py"
spec = importlib.util.spec_from_file_location("mock_publisher_module", PUBLISHER_PATH)
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)  # type: ignore


class FakeResult:
    def __init__(self, mid: int) -> None:
        self.rc = 0
        self.mid = mid

    def wait_for_publish(self) -> None:
        return None


class FakeClient:
    def __init__(self) -> None:
        self.on_connect = None
        self.on_disconnect = None
        self.on_message = None
        self._callbacks = {}
        self.subscriptions = []
        self.published = []
        self.mid = 1

    # pylint: disable=unused-argument
    def username_pw_set(self, username: str, password: str) -> None:
        return None

    def will_set(self, topic: str, payload: str, qos: int, retain: bool) -> None:
        self.will = (topic, payload, qos, retain)

    def connect(self, host: str, port: int, keepalive: int) -> None:
        if self.on_connect:
            self.on_connect(self, None, None, 0)

    def loop_start(self) -> None:
        return None

    def loop_stop(self) -> None:
        return None

    def disconnect(self) -> None:
        if self.on_disconnect:
            self.on_disconnect(self, None, 0)

    def publish(self, topic: str, payload: str, qos: int = 0, retain: bool = False):
        self.published.append((topic, payload, qos, retain))
        res = FakeResult(self.mid)
        self.mid += 1
        return res

    def subscribe(self, topic: str, qos: int = 0) -> None:
        self.subscriptions.append((topic, qos))

    def message_callback_add(self, topic: str, callback) -> None:
        self._callbacks[topic] = callback

    def simulate_message(self, topic: str, payload: bytes) -> None:
        message = types.SimpleNamespace(topic=topic, payload=payload)
        if topic in self._callbacks:
            self._callbacks[topic](self, None, message)
        elif self.on_message:
            self.on_message(self, None, message)


class LogServiceTest(unittest.TestCase):
    def setUp(self) -> None:
        publisher.log_buffer.dump(clear=True)
        self._orig_client = publisher.mqtt.Client
        self.fake_client = FakeClient()

        def client_factory(*_args, **_kwargs):
            return self.fake_client

        publisher.mqtt.Client = client_factory
        publisher.running = True

    def tearDown(self) -> None:
        publisher.mqtt.Client = self._orig_client
        publisher.running = True
        publisher.log_buffer.dump(clear=True)

    def test_log_dump_flow(self) -> None:
        args = argparse.Namespace(
            host="localhost",
            port=1883,
            username="dev1",
            password="dev1pass",
            device_id="dev1",
            interval=1,
            base_weight=1234.0,
            rssi=-62,
            services=None,
            enable_logs=True,
            dry_run=False,
        )

        thread = threading.Thread(target=publisher.run, args=(args,), daemon=True)
        thread.start()
        time.sleep(0.1)

        cmd_logs_topic = next(t for (t, _q) in self.fake_client.subscriptions if t.endswith("/cmd/logs"))
        self.fake_client.simulate_message(cmd_logs_topic, b'{"clear": false}')
        time.sleep(0.05)

        event_payloads = [json.loads(p) for (t, p, _q, _r) in self.fake_client.published if t.endswith("/event/log")]
        self.assertTrue(event_payloads)
        last_dump = event_payloads[-1]
        self.assertEqual(last_dump["device"], "dev1")
        self.assertGreaterEqual(last_dump["count"], 1)

        self.fake_client.simulate_message(cmd_logs_topic, b'{"clear": true}')
        time.sleep(0.05)
        event_payloads = [json.loads(p) for (t, p, _q, _r) in self.fake_client.published if t.endswith("/event/log")]
        cleared_dump = event_payloads[-1]
        self.assertEqual(cleared_dump["count"], 0)

        publisher.stop_loop(None)
        thread.join(timeout=1)


if __name__ == "__main__":
    unittest.main()
