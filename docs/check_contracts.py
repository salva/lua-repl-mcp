#!/usr/bin/env python3
"""Validate documentation contracts; requires jsonschema==4.19.2."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.request import urlopen

from jsonschema import Draft202012Validator

DOCS = Path(__file__).resolve().parent
UPSTREAM = (
    "https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/"
    "86f6e0c675afea9a8f233e09b6faf566b126086c/schema/2025-11-25/schema.json"
)
SHA256 = "268a5f82ba70fd7e4b6dc4aa1e64f116f74b4d0edcb69dc046829c79dd4e97e7"
MANAGER = ["session_create", "session_execute", "session_wait", "session_kill", "session_list"]
DIRECT = ["repl_execute", "repl_close"]
DESCRIPTIONS = {
    "session_create": "Create a persistent Lua interpreter. Request cancellation aborts allocation and destroys its state.",
    "session_execute": "Execute a complete Lua chunk; explicit return is required. Omitted/null session_id creates an interpreter. Globals persist; locals do not. No automatic output capture. Accepted execution discards unread prior results. Terminal replies consume results. wait_timeout_ms defaults to 600000; null waits indefinitely, zero returns pending. Wait expiry leaves execution running. execution_timeout_ms is a separate hard deadline that kills the session. Request cancellation also kills the session and destroys state. Execution is not read-only or idempotent.",
    "session_wait": "Retrieve the current execution without rerunning it. Zero polls; null waits indefinitely; default 600000 ms. Terminal retrieval consumes the result; pending replies do not. Request cancellation kills the session and destroys state, unlike a wait deadline.",
    "session_kill": "Destroy session state with synchronous best-effort disposal; retain no history. Unconfirmed OS exit is reported without failing the kill operation.",
    "session_list": "List existing sessions, not history. An unknown session after asynchronous work does not imply code never ran or that retrying side effects is safe.",
    "repl_execute": "Synchronously execute a complete Lua chunk in the host interpreter. Globals persist; locals do not. Use explicit return for values. No automatic output capture. Execution is not read-only or idempotent; no managed timeout or cancellation killing the host is supported.",
    "repl_close": "Acknowledge and return control to the parent without closing transport or changing host state; the parent decides what happens afterward.",
}


def expand(node, definitions, stack=()):
    """Inline local refs, preserving sibling constraints (not a shallow merge)."""
    if isinstance(node, list):
        return [expand(item, definitions, stack) for item in node]
    if not isinstance(node, dict):
        return node
    siblings = {k: expand(v, definitions, stack) for k, v in node.items() if k != "$ref"}
    if "$ref" not in node:
        return siblings
    ref = node["$ref"]
    if not ref.startswith("#/$defs/") or ref in stack:
        raise ValueError(f"Unsupported or cyclic reference: {ref}")
    target = expand(definitions[ref.removeprefix("#/$defs/")], definitions, stack + (ref,))
    if not siblings:
        return target
    return {**siblings, "allOf": siblings.get("allOf", []) + [target]}


def check_examples(validators, official):
    requests = {}
    count = 0
    pattern = r"(?:<!-- schema: (\w+) -->\s*)?```json\n(.*?)\n```"
    for match in re.finditer(pattern, (DOCS / "MCP_EXAMPLES.md").read_text(), re.S):
        schema, text = match.groups()
        value = json.loads(text)
        if schema:
            validators[schema].validate(value)
        elif value.get("method") == "tools/call":
            official("CallToolRequest").validate(value)
            params = value["params"]
            requests[value["id"]] = params["name"]
            validators[params["name"]].validate(params["arguments"])
        elif "result" in value and "structuredContent" in value["result"]:
            result = value["result"]
            official("CallToolResult").validate(result)
            payload = result["structuredContent"]
            validators[requests[value["id"]] + "_output"].validate(payload)
            assert result["isError"] == ("error" in payload)
            assert json.loads(result["content"][0]["text"]) == payload
        else:
            kind = {
                "initialize": "InitializeRequest",
                "notifications/initialized": "InitializedNotification",
                "notifications/cancelled": "CancelledNotification",
            }.get(value.get("method"), "InitializeResult" if "result" in value else None)
            assert kind, f"Unclassified JSON example: {value}"
            official(kind).validate(value["result"] if kind == "InitializeResult" else value)
        count += 1
    assert count >= 20, "Examples unexpectedly missing"
    return count


def regressions(validators):
    count = 0

    def expect(name, payload, valid=True):
        nonlocal count
        actual = validators[name].is_valid(payload)
        assert actual == valid, f"{name}: expected valid={valid}: {payload}"
        count += 1

    def error(code="invalid_arguments", **extra):
        return {"code": code, "message": "Diagnostic", "stage": "validation", "execution_state": "unknown", **extra}

    known = {"session_id": "s1", "session_status": "idle", "session_usable": True}
    for name in MANAGER + DIRECT:
        output = name + "_output"
        expect(output, {"error": error()})  # Admission/validation can precede lookup.
        expect(output, [], False)

    for name in ("session_execute_output", "session_wait_output", "session_kill_output"):
        unknown = {"session_id": "removed", "session_usable": False, "error": error("unknown_session")}
        expect(name, unknown)
        for key in ("session_id", "session_usable"):
            expect(name, {k: v for k, v in unknown.items() if k != key}, False)
        for extra in ({"session_id": ""}, {"session_usable": True}, {"session_status": "terminated"}, {"status": "failed"}):
            expect(name, {**unknown, **extra}, False)

    for name in ("session_create_output", "session_execute_output", "session_wait_output"):
        for nested in (False, True):
            payload = {"error": error("session_creation_error")}
            (payload["error"] if nested else payload)["process_exit_confirmed"] = False
            expect(name, payload, False)
            expect(name, {**payload, "notice": ""}, False)
            expect(name, {**payload, "notice": "Process may remain alive."})

    for name in ("session_execute_output", "session_wait_output"):
        expect(name, {"error": error("session_busy")}, False)
        for status, code in (("running", "session_busy"), ("completed", "result_unavailable"), ("failed", "lua_runtime_error")):
            payload = {**known, "status": status, "error": error(code)}
            expect(name, payload)
            for key in known:
                expect(name, {k: v for k, v in payload.items() if k != key}, False)
        expect(name, {**known, "error": error("no_execution")})
        # A recorded completion can survive subsequent worker termination.
        expect(name, {**known, "session_status": "terminated", "session_usable": False, "status": "completed", "values": []})
        for status in ("killed", "closing"):
            expect(name, {**known, "status": status, "error": error()}, False)

    expect("session_create_output", {"session_id": "s1", "session_status": "idle"})
    expect("session_create_output", {"session_id": "s1", "session_status": "idle", "error": error("session_creation_error")}, False)
    kill = {"session_id": "s1", "session_usable": False, "status": "killed", "process_exit_confirmed": True}
    expect("session_kill_output", kill)
    expect("session_kill_output", {**kill, "process_exit_confirmed": False}, False)
    expect("session_kill_output", {**kill, "process_exit_confirmed": False, "notice": "May remain alive."})
    for name in ("session_create_output", "session_list_output", "repl_close_output"):
        expect(name, {"status": "failed", "error": error()}, False)
    for name in ("session_list_output", "repl_execute_output", "repl_close_output"):
        for key, value in known.items():
            expect(name, {key: value, "error": error()}, False)
    expect("repl_execute_output", {"status": "running", "error": error()}, False)
    expect("repl_execute_output", {"status": "failed", "error": error("lua_runtime_error")})
    expect("repl_execute_output", {"status": "completed", "values": []})
    expect("repl_close_output", {"status": "closing"})
    expect("session_list_output", {"sessions": []})
    expect("session_execute_output", {**known, "status": "completed"}, False)
    expect("session_execute_output", {**known, "status": "running", "values": []}, False)
    expect("session_execute_output", {**known, "error": error(), "values": []}, False)
    for value in (None, 0, 2147483647):
        expect("session_execute", {"code": "", "wait_timeout_ms": value})
    for value in (-1, 0.5, 2147483648):
        expect("session_execute", {"code": "", "wait_timeout_ms": value}, False)
    expect("session_execute", {"code": "", "execution_timeout_ms": 0}, False)
    expect("session_execute", {"code": "", "create_options": {}})
    expect("session_execute", {"code": "", "session_id": "s1", "create_options": {}}, False)
    for name in ("session_wait", "session_kill"):
        expect(name, {"session_id": None}, False)
    expect("repl_execute", {"code": "", "session_id": "s1"}, False)
    args = {"code": ""}
    expect("session_execute", args)
    assert args == {"code": ""}, "Validation must not apply runtime defaults"
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mcp-schema", type=Path, help="Offline copy of pinned official schema")
    parser.add_argument("--discovery", action="store_true", help="Print both tools/list result examples")
    args = parser.parse_args()
    raw = args.mcp_schema.read_bytes() if args.mcp_schema else urlopen(UPSTREAM, timeout=30).read()
    assert hashlib.sha256(raw).hexdigest() == SHA256, "Official schema digest mismatch"
    upstream = json.loads(raw)

    def official(name):
        return Draft202012Validator({"$ref": f"#/$defs/{name}", "$defs": upstream["$defs"]})

    document = json.loads((DOCS / "schemas/api.json").read_text())
    Draft202012Validator.check_schema(document)
    schemas = {}
    for name in MANAGER + DIRECT:
        for key in (name, name + "_output"):
            assert document["$defs"][key].get("type") == "object", key
            schemas[key] = {"$schema": document["$schema"], **expand(document["$defs"][key], document["$defs"])}
            Draft202012Validator.check_schema(schemas[key])
            assert '"$ref"' not in json.dumps(schemas[key])
    validators = {k: Draft202012Validator(v) for k, v in schemas.items()}
    for names in (MANAGER, DIRECT):
        result = {"tools": [{"name": n, "description": DESCRIPTIONS[n], "inputSchema": schemas[n], "outputSchema": schemas[n + "_output"]} for n in names]}
        official("ListToolsResult").validate(result)
        for tool in result["tools"]:
            official("Tool").validate(tool)
            for key in ("inputSchema", "outputSchema"):
                broken = deepcopy(tool)
                del broken[key]["type"]
                assert not official("Tool").is_valid(broken), "MCP root-type regression not detected"
        if args.discovery:
            print(json.dumps(result, indent=2))
    examples = check_examples(validators, official)
    fixtures = regressions(validators)
    print(f"PASS: 14 standalone schemas, 7 official MCP Tools, 2 discovery results, {examples} examples, {fixtures} regression cases", file=sys.stderr)


if __name__ == "__main__":
    main()
