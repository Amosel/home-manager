#!/usr/bin/env python3
"""Process-local GPT-OSS compatibility; never rewrites installed packages.

Upstream currently cleans Harmony before nonstream tool parsing and suppresses
commentary in its streaming reasoning parser. Apply only failing behavior probes.
"""
import inspect
import re
import sys

CHANNEL = re.compile(r"<\|channel\|>(analysis|final|commentary)[^<]*(?:<\|constrain\|>[^<]*)?<\|message\|>")
STRUCTURAL = re.compile(r"<\|(?:start|end|channel|return|call|constrain)\|>")
FIXTURE = '<|channel|>commentary to=functions.get_temperature <|constrain|>json<|message|>{"city":"Paris"}'


TOKENS = tuple("<|" + name + "|>" for name in ("start", "end", "channel", "message", "return", "call", "constrain"))


def hold_token_prefix(text):
    for size in range(1, min(len(text), max(map(len, TOKENS))) + 1):
        if any(token.startswith(text[-size:]) and token != text[-size:] for token in TOKENS):
            return text[:-size]
    return text


def project(text):
    """Cumulative safe reasoning/content, withholding incomplete control tokens."""
    matches = list(CHANNEL.finditer(text))
    if not matches:
        # A complete channel token starts a header, never user-visible prose.
        return "", hold_token_prefix(text.split("<|channel|>", 1)[0].split("<|start|>", 1)[0])
    reasoning, content = "", ""
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[match.end():end]
        if match[1] == "commentary" and "to=functions." in match[0]:
            # Keep call/end terminators, but not the next assistant/channel header.
            body = re.split(r"<\|(?:start|channel)\|>", body, maxsplit=1)[0]
            content += text[match.start():match.end()] + hold_token_prefix(body)
        else:
            body = STRUCTURAL.split(body, maxsplit=1)[0]
            body = hold_token_prefix(body)
            if match[1] == "analysis":
                reasoning += body
            else:
                content += body
    return reasoning, content


def streaming(self, previous_text, current_text, delta_text):
    from vllm_mlx.reasoning.base import DeltaMessage
    before, after = project(previous_text), project(current_text)
    if any(not new.startswith(old) for old, new in zip(before, after)):
        raise RuntimeError("GPT-OSS compatibility: unsupported Harmony channel transition")
    reasoning, content = (new[len(old):] for old, new in zip(before, after))
    return DeltaMessage(reasoning=reasoning or None, content=content or None) if reasoning or content else None


def install():
    from vllm_mlx.engine import simple, batched
    from vllm_mlx.reasoning.gpt_oss_parser import GptOssReasoningParser
    from vllm_mlx.tool_parsers.harmony_tool_parser import HarmonyToolParser
    from vllm_mlx import server
    parser = HarmonyToolParser(None)
    if not parser.extract_tool_calls(FIXTURE).tools_called:
        raise RuntimeError("GPT-OSS compatibility: upstream Harmony parser contract changed")
    if not callable(getattr(server, "_finalize_streaming_tool_result", None)):
        raise RuntimeError("GPT-OSS compatibility: upstream streaming finalizer changed")
    applied = []
    for module in (simple, batched):
        original = getattr(module, "clean_output_text", None)
        if not callable(original):
            raise RuntimeError("GPT-OSS compatibility: upstream engine cleaner changed")
        if original(FIXTURE) != FIXTURE:
            def preserve(text, original=original):
                return text if "<|channel|>" in text else original(text)
            module.clean_output_text = preserve
            applied.append(module.__name__.rsplit(".", 1)[-1] + "-raw-harmony")
    method = GptOssReasoningParser.extract_reasoning_streaming
    if list(inspect.signature(method).parameters) != ["self", "previous_text", "current_text", "delta_text"]:
        raise RuntimeError("GPT-OSS compatibility: upstream reasoning signature changed")
    result = GptOssReasoningParser().extract_reasoning_streaming("", FIXTURE, FIXTURE)
    if result is None or result.content != FIXTURE:
        GptOssReasoningParser.extract_reasoning_streaming = streaming
        applied.append("commentary-stream")
    print("GPT-OSS compatibility: " + (", ".join(applied) or "upstream passes; no overrides"), file=sys.stderr)
    return applied


if __name__ == "__main__":
    install()
    from vllm_mlx.cli import main
    main()
