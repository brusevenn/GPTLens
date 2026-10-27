import unittest

from openai import OpenAI


class OpenAIHttpxCompatibilityTests(unittest.TestCase):
    def test_openai_client_constructs_without_network(self):
        client = OpenAI(
            api_key="test-key-not-a-credential",
            base_url="https://api.example.invalid/v1",
        )
        client.close()


if __name__ == "__main__":
    unittest.main()
