import argparse
import json
import threading
import time
import unittest

from . import test_logs as helpers

publisher = helpers.publisher
FakeClient = helpers.FakeClient


class OtaServiceTest(unittest.TestCase):
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

    def test_ota_progress_sequence(self) -> None:
        args = argparse.Namespace(
            host="localhost",
            port=1883,
            username="dev1",
            password="dev1pass",
            device_id="sf-mock01",
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

        cmd_root = next(t for (t, _q) in self.fake_client.subscriptions if t.endswith("/cmd"))
        cmd_ota_topic = f"{cmd_root}/ota"
        payload = json.dumps({"url": "mock.bin", "size": 4096})
        self.fake_client.simulate_message(cmd_ota_topic, payload.encode("utf-8"))
        time.sleep(0.3)

        event_payloads = [
            json.loads(p)
            for (t, p, _q, _r) in self.fake_client.published
            if t.endswith("/event/ota")
        ]
        self.assertGreaterEqual(len(event_payloads), 5)
        progress_points = [entry.get("progress") for entry in event_payloads[:5]]
        self.assertEqual(progress_points, [0, 25, 50, 75, 100])
        final_event = event_payloads[-1]
        self.assertEqual(final_event.get("status"), "verified")
        self.assertEqual(final_event.get("size"), 4096)
        crc_value = final_event.get("crc")
        self.assertIsInstance(crc_value, str)
        self.assertRegex(crc_value, r"^[0-9A-F]{8}$")

        publisher.stop_loop(None)
        thread.join(timeout=1)


if __name__ == "__main__":
    unittest.main()
