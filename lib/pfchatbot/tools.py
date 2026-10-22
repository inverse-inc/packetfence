"""Tool schemas for NACBot.

Pure data: the JSON-schema definitions the model sees, plus the human labels
shown in the activity trace. Nothing here touches the API client, the database
or any runtime state — the implementations behind these names live in app.py's
`dispatch()`, so a schema change and a behaviour change stay separate edits.

Imported by app.py:  from tools import TOOLS, label
"""
from __future__ import annotations

TOOLS = [
    {
        "name": "pf_search_operations",
        "description": "Semantic search over PacketFence OpenAPI operations for the current version. "
                       "Use FIRST whenever the user wants LIVE DATA or an ACTION on the running "
                       "system — anything phrased as show/list/get/find/display/count, or a change "
                       "like add/create/register/remove/delete/deregister/assign/set/update/"
                       "enable/disable/move. Finds the endpoint that does it.",
        "parameters": {
            "type": "object",
            "properties": {"query": {"type": "string"}, "limit": {"type": "integer"}},
            "required": ["query"],
        },
    },
    {
        "name": "pf_describe_operation",
        "description": "Get the exact parameters and request-body schema for one operation_id. "
                       "Call before pf_call_operation.",
        "parameters": {
            "type": "object",
            "properties": {"operation_id": {"type": "string"}},
            "required": ["operation_id"],
        },
    },
    {
        "name": "pf_call_operation",
        "description": "Execute a PacketFence API operation by operation_id, supplying any path/query params and body.",
        "parameters": {
            "type": "object",
            "properties": {
                "operation_id": {"type": "string"},
                "path_params": {"type": "object"},
                "query_params": {"type": "object"},
                "body": {"type": "object"},
            },
            "required": ["operation_id"],
        },
    },
    {
        "name": "pf_search_docs",
        "description": "Semantic search over the PacketFence documentation (guides). Use for "
                       "KNOWLEDGE and HOW-TO questions — how to do something, step-by-step "
                       "procedures, configuration instructions, concepts, requirements, or 'what "
                       "is / how does / why' explanations. This is the source for anything the "
                       "user needs to LEARN or follow, as opposed to live system data.",
        "parameters": {
            "type": "object",
            "properties": {"query": {"type": "string"}, "limit": {"type": "integer"}},
            "required": ["query"],
        },
    },
    {
        "name": "pf_search_logs",
        "description": "Search PacketFence logs (radius.log, packetfence.log) for a specific MAC "
                       "address OR a username, and return matching lines. Use this to troubleshoot "
                       "why a device or user failed authentication, was rejected, or hit an error. "
                       "Search by MAC for MAB/device issues; search by username for 802.1X/EAP "
                       "issues (the identity like 'testnew'). MAC formats are matched automatically. "
                       "Provide exactly one of mac or username. After retrieving lines, interpret "
                       "them: identify rejects, auth failures, policy/role decisions, likely causes.",
        "parameters": {
            "type": "object",
            "properties": {
                "mac": {"type": "string", "description": "MAC address in any format"},
                "username": {"type": "string", "description": "802.1X/EAP identity / username"},
                "which": {"type": "string", "enum": ["radius", "packetfence", "both"],
                          "description": "which log(s) to search; default both"},
                "limit": {"type": "integer", "description": "max matching lines per log (default 80)"},
            },
        },
    },
    {
        "name": "pf_diagnose",
        "description": "One-shot end-to-end triage for a device or user having authentication "
                       "problems. Give a MAC (device/MAB) or username (802.1X/EAP). It looks up "
                       "the node, searches the logs, and finds the most recent RADIUS result, "
                       "returning all evidence together. PREFER THIS when the user asks to "
                       "troubleshoot/diagnose/why-did-X-fail, instead of calling the individual "
                       "tools separately. Read-only. Then explain the diagnosis and the fix.",
        "parameters": {
            "type": "object",
            "properties": {
                "mac": {"type": "string", "description": "device MAC (any format)"},
                "username": {"type": "string", "description": "802.1X/EAP identity"},
            },
        },
    },
    {
        "name": "pf_run_test",
        "description": "Prepare an authentication test against PacketFence RADIUS. Use when the "
                       "user wants to TEST/verify credentials or a device: eapol_test for 802.1X "
                       "user auth (a username + password, PEAP/MSCHAPv2), or radclient for MAB "
                       "(a MAC address as both username and password). Pick the tool from what the "
                       "user gives: a human-style username+password => eapol_test PEAP; a MAC "
                       "address => radclient. This does NOT run the test; it opens and fills the "
                       "Test Tools panel for the user to review and run. Tell the user the panel is "
                       "prepared and to review then click Run.",
        "parameters": {
            "type": "object",
            "properties": {
                "tool": {"type": "string", "enum": ["eapol_test", "radclient"]},
                "username": {"type": "string", "description": "username (eapol) or MAC (radclient)"},
                "password": {"type": "string", "description": "password (eapol); for radclient defaults to the MAC"},
                "nas_ip": {"type": "string", "description": "radclient only: NAS-IP matching switches.conf"},
            },
            "required": ["tool", "username"],
        },
    },
    {
        "name": "pf_roles",
        "description": "List PacketFence roles with their NUMERIC category_id, read live from "
                       "the node_categories endpoint. Call this before changing a node's role: a node PATCH "
                       "needs category_id as a number, while the config API identifies roles by "
                       "name — so 'gaming' must become 3. Optionally pass name to resolve one "
                       "role. Newly created roles appear immediately.",
        "parameters": {
            "type": "object",
            "properties": {"name": {"type": "string",
                                    "description": "optional role name to resolve"}},
        },
    },
    {
        "name": "pf_describe_fields",
        "description": "Ask PacketFence (via an OPTIONS request) which fields a resource "
                       "accepts: their types, which are REQUIRED, any validation pattern, and "
                       "the allowed values. Call this BEFORE any create/update "
                       "(pf_call_operation on a POST/PUT/PATCH) so the body is right first "
                       "time instead of guessing and getting a 422. Give it the operation_id "
                       "you are about to call, or a path like /nodes.",
        "parameters": {
            "type": "object",
            "properties": {"target": {"type": "string",
                                      "description": "operation_id or resource path"}},
            "required": ["target"],
        },
    },
    {
        "name": "pf_node_details",
        "description": "Fetch one node's record by MAC and return its fields (status, "
                       "registration, owner/pid, device type, last seen, roles, notes). Use "
                       "this for ANY plain request about a single device — 'details of <mac>', "
                       "'info about <mac>', 'show node <mac>', 'what is <mac>'. It resolves the "
                       "node-view endpoint itself, so do NOT search for an operation first. "
                       "Read-only: it does not touch logs and is not a diagnosis.",
        "parameters": {
            "type": "object",
            "properties": {"mac": {"type": "string", "description": "device MAC in any format"}},
            "required": ["mac"],
        },
    },
    {
        "name": "pf_write_file",
        "description": "Save output as a downloadable file for the user (CSV, TXT, JSON, "
                       "config, a log extract...). Use when the user asks to export, save "
                       "or download something, or when a result is long enough to be more "
                       "useful as a file than as chat text — e.g. a full node list as CSV. "
                       "The file appears as a download link under your reply and in the "
                       "conversation's Files panel. Give it a sensible filename with an "
                       "extension. Do not use this for short answers that belong in chat.",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "filename with extension, e.g. nodes.csv"},
                "content": {"type": "string", "description": "the full text content of the file"},
                "mime": {"type": "string", "description": "optional MIME type, e.g. text/csv"},
            },
            "required": ["name", "content"],
        },
    },
    {
        "name": "pf_list_files",
        "description": "List the files attached to this conversation — both files the user "
                       "uploaded and files you produced. Use before reading a file, or when "
                       "the user refers to 'the file I uploaded' without naming it.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "name": "pf_read_file",
        "description": "Read the contents of a file in this conversation (usually one the "
                       "user uploaded). Uploaded files are NOT indexed for search — this is "
                       "the only way to see them. Large files are returned in slices: pass "
                       "offset/length and call again to continue rather than trying to read "
                       "a huge file at once.",
        "parameters": {
            "type": "object",
            "properties": {
                "file_id": {"type": "integer", "description": "id from pf_list_files"},
                "name": {"type": "string", "description": "or match by filename"},
                "offset": {"type": "integer", "description": "byte offset to start at (default 0)"},
                "length": {"type": "integer", "description": "bytes to return, max 40000"},
            },
        },
    },
    {
            "name": "pf_capture",
            "description": "Prepare a bounded packet capture (tcpdump) on the PacketFence host and, "
                           "after it runs, analyze a structured tshark summary. Use when the user wants "
                           "to capture/sniff traffic or see what's on the wire for RADIUS, DHCP, DNS, "
                           "EAP/EAPOL, or a specific host/MAC. Choose a preset (radius/dhcp/dns/eap/all) "
                           "or provide a simple BPF filter (e.g. 'host 10.0.0.5 and udp port 1812'). "
                           "This does NOT start the capture; it opens a capture panel for the user to "
                           "review (interface, filter, limits) and run. Only a structured summary — no "
                           "raw packet payloads — is ever analyzed. Tell the user to review and click Run.",
            "parameters": {
                "type": "object",
                "properties": {
                    "iface": {"type": "string", "description": "network interface to capture on, e.g. eth0 (if the user names one)"},
                    "preset": {"type": "string", "enum": ["radius", "dhcp", "dns", "eap", "all"]},
                    "filter": {"type": "string", "description": "optional BPF filter (overrides preset)"},
                    "seconds": {"type": "integer", "description": "capture duration, capped at 60"},
                    "packets": {"type": "integer", "description": "max packets, capped at 500"},
                },
            },
        },
    ]


def label(name: str, i: dict) -> str:
    return {
        "pf_search_operations": f'searching operations: "{i.get("query","")}"',
        "pf_describe_operation": f'inspecting {i.get("operation_id","")}',
        "pf_call_operation": f'calling {i.get("operation_id","")}',
        "pf_search_docs": f'searching docs: "{i.get("query","")}"',
        "pf_search_logs": f'searching logs for {i.get("mac") or i.get("username") or "?"}',
        "pf_diagnose": f'diagnosing {i.get("mac") or i.get("username") or "?"}',
        "pf_run_test": f'preparing {i.get("tool","")} test',
        "pf_roles": f'resolving role {i.get("name","") or "list"}',
        "pf_describe_fields": f'checking fields for {i.get("target","")}',
        "pf_node_details": f'fetching node {i.get("mac","")}',
        "pf_write_file": f'writing file {i.get("name","")}',
        "pf_list_files": 'listing conversation files',
        "pf_read_file": f'reading file {i.get("name") or i.get("file_id") or "?"}',
    }.get(name, name)
