import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch


SCRIPT = Path(__file__).parents[1] / "scripts" / "evaluate_baseline.py"
SPEC = importlib.util.spec_from_file_location("evaluate_baseline", SCRIPT)
evaluate_baseline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(evaluate_baseline)


class PostWithRateLimitRetriesTests(unittest.TestCase):
    @patch.object(evaluate_baseline.time, "sleep")
    @patch.object(evaluate_baseline.requests, "post")
    def test_retries_429_using_retry_after_ms(self, post, sleep):
        throttled = Mock(status_code=429, headers={"retry-after-ms": "1500"})
        success = Mock(status_code=200)
        post.side_effect = [throttled, success]

        response = evaluate_baseline.post_with_rate_limit_retries("https://example.test", headers={}, json_body={})

        self.assertIs(response, success)
        sleep.assert_called_once_with(1.5)
        self.assertEqual(post.call_count, 2)

    @patch.object(evaluate_baseline.time, "sleep")
    @patch.object(evaluate_baseline.requests, "post")
    def test_retries_using_retry_after_seconds(self, post, sleep):
        throttled = Mock(status_code=429, headers={"retry-after": "3"})
        success = Mock(status_code=200)
        post.side_effect = [throttled, success]

        evaluate_baseline.post_with_rate_limit_retries("https://example.test", headers={}, json_body={})

        sleep.assert_called_once_with(3)

    @patch.object(evaluate_baseline.time, "sleep")
    @patch.object(evaluate_baseline.requests, "post")
    def test_raises_after_retry_limit(self, post, sleep):
        throttled = Mock(status_code=429, headers={})
        throttled.raise_for_status.side_effect = RuntimeError("429")
        post.return_value = throttled

        with self.assertRaisesRegex(RuntimeError, "429"):
            evaluate_baseline.post_with_rate_limit_retries("https://example.test", headers={}, json_body={})

        self.assertEqual(post.call_count, evaluate_baseline.MAX_RATE_LIMIT_RETRIES + 1)
        self.assertEqual(sleep.call_count, evaluate_baseline.MAX_RATE_LIMIT_RETRIES)


if __name__ == "__main__":
    unittest.main()
