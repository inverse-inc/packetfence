# Copyright (C) Inverse inc.
# Comware cliconf for PacketFence PushACLs. Based on the H3C comware cliconf,
# with the enable_mode decorators removed: Comware has no enable mode, so
# @enable_mode wrongly triggered "operation requires privilege escalation".
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = """
---
author: Inverse inc.
name: comware
short_description: Use comware cliconf to run commands on Comware 7 / NEC QX-S
description:
  - Low-level abstraction APIs for sending and receiving CLI commands to and
    from H3C/HPE Comware 7 (and rebranded, e.g. NEC QX-S) network devices.
"""

import json
import re
from itertools import chain

from ansible.module_utils.common.text.converters import to_text
from ansible_collections.ansible.netcommon.plugins.module_utils.network.common.utils import (
    to_list,
)
from ansible.plugins.cliconf import CliconfBase


class Cliconf(CliconfBase):

    def get_device_info(self):
        device_info = {}
        device_info["network_os"] = "comware"
        reply = self.get("display version")
        data = to_text(reply, errors="surrogate_or_strict").strip()
        match = re.search(r"Version\s+(\S+)", data)
        if match:
            device_info["network_os_version"] = match.group(1).strip(",")
        match = re.search(r"([\w\-]+)\s+uptime", data, re.M)
        if match:
            device_info["network_os_hostname"] = match.group(1)
        return device_info

    def get_config(self, source="running", flags=None, format="text"):
        if source not in ("running", "startup"):
            raise ValueError("fetching configuration from %s is not supported" % source)
        cmd = "display current-configuration" if source == "running" else "display saved-configuration"
        return self.send_command(cmd)

    def edit_config(self, candidate=None, commit=True, replace=False, comment=None):
        results = []
        requests = []
        for cmd in chain(["system-view"], to_list(candidate), ["return"]):
            if isinstance(cmd, dict):
                command = cmd["command"]
                prompt = cmd.get("prompt")
                answer = cmd.get("answer")
                newline = cmd.get("newline", True)
            else:
                command = cmd
                prompt = answer = None
                newline = True
            results.append(self.send_command(command=command, prompt=prompt, answer=answer, newline=newline))
            requests.append(command)
        return {"request": requests, "response": results}

    def get(self, command=None, prompt=None, answer=None, sendonly=False, newline=True, output=None, check_all=False):
        if output:
            raise ValueError("'output' value %s is not supported for get" % output)
        return self.send_command(command=command, prompt=prompt, answer=answer, sendonly=sendonly, newline=newline, check_all=check_all)

    def get_capabilities(self):
        result = super(Cliconf, self).get_capabilities()
        return json.dumps(result)
