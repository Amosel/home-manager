"""Run with ~/.venvs/vllm-mlx/bin/python -m unittest discover -s tests."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('compat', Path(__file__).parents[1] / 'scripts/local-llm-gpt-oss-compat.py')
compat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compat)
compat.install()
from vllm_mlx.engine import simple, batched
from vllm_mlx.reasoning.gpt_oss_parser import GptOssReasoningParser
from vllm_mlx.tool_parsers.harmony_tool_parser import HarmonyToolParser
from vllm_mlx import server

ANALYSIS = '<|channel|>analysis<|message|>private thought<|end|><|start|>assistant'
FINAL = '<|channel|>final<|message|>17 degrees<|return|>'

class CompatibilityTests(unittest.TestCase):
    def test_nonstream_raw_survives_and_reasoning_separates(self):
        raw = ANALYSIS + compat.FIXTURE
        for engine in (simple, batched):
            self.assertEqual(engine.clean_output_text(raw), raw)
        reasoning, content = GptOssReasoningParser().extract_reasoning(raw)
        self.assertEqual(reasoning, 'private thought')
        self.assertIsNone(content)
        parsed = HarmonyToolParser(None).extract_tool_calls(server._strip_harmony_analysis_blocks(raw))
        self.assertEqual(len(parsed.tool_calls), 1)
        self.assertIsNone(parsed.content)

    def test_split_chunks_and_eof_call_exactly_once(self):
        for size in (1, 2, 7, 10000):
            for ending in ('', '<|call|>'):
                raw = ANALYSIS + compat.FIXTURE + ending
                accumulated = ''; tool_text = ''; reasoning = ''; calls = []
                tool = HarmonyToolParser(None)
                for start in range(0, len(raw), size):
                    delta = raw[start:start + size]
                    message = compat.streaming(None, accumulated, accumulated + delta, delta)
                    accumulated += delta
                    if not message: continue
                    reasoning += message.reasoning or ''
                    if message.content:
                        previous = tool_text; tool_text += message.content
                        result = tool.extract_tool_calls_streaming(previous, tool_text, message.content)
                        if result: calls.extend(result.get('tool_calls', []))
                if not calls:
                    result = tool.extract_tool_calls(tool_text)
                    calls.extend({'function': {'name': c['name'], 'arguments': c['arguments']}} for c in result.tool_calls)
                self.assertEqual(len(calls), 1, (size, ending, calls))
                self.assertEqual(calls[0]['function']['name'], 'get_temperature')
                self.assertNotIn('private thought', tool_text)
                self.assertEqual(reasoning, 'private thought')

    def test_final_split_no_reasoning_or_markers(self):
        text = ''; content = ''; reasoning = ''
        for char in ANALYSIS + FINAL:
            result = compat.streaming(None, text, text + char, char); text += char
            if result:
                content += result.content or ''; reasoning += result.reasoning or ''
        self.assertEqual(content, '17 degrees')
        self.assertEqual(reasoning, 'private thought')

    def test_commentary_to_final_monotonic(self):
        text = ''; content = ''
        raw = '<|channel|>commentary<|message|>Checking.<|end|><|start|>assistant' + FINAL
        for char in raw:
            result = compat.streaming(None, text, text + char, char); text += char
            if result: content += result.content or ''
        self.assertEqual(content, 'Checking.17 degrees')
        self.assertNotIn('<|start|>', content)
        self.assertNotIn('<|channel|>final', content)

    def test_ordinary_text(self):
        self.assertEqual(compat.project('Hello world'), ('', 'Hello world'))
        self.assertEqual(compat.project('2 < 3'), ('', '2 < 3'))
        text = ''; content = ''
        for char in '2 < 3':
            result = compat.streaming(None, text, text + char, char); text += char
            if result: content += result.content or ''
        self.assertEqual(content, '2 < 3')
        self.assertEqual(simple.clean_output_text('Hello world'), 'Hello world')

if __name__ == '__main__': unittest.main()
