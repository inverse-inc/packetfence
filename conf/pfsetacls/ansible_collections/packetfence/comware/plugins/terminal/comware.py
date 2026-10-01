# Copyright (C) Inverse inc.
# Corrected Comware terminal plugin for PacketFence PushACLs.
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import re

from ansible.errors import AnsibleConnectionFailure
from ansible.module_utils.common.text.converters import to_bytes
from ansible_collections.ansible.netcommon.plugins.plugin_utils.terminal_base import (
    TerminalBase,
)


class TerminalModule(TerminalBase):

    # Comware user view prompt is <hostname>; system-view and sub-views are
    # [hostname] / [hostname-view]. Match both (the upstream h3c plugin only
    # matched >/#/% and hung in config views).
    terminal_stdout_re = [
        re.compile(to_bytes(r"[\r\n]?[<\[][\-\w\.\+:/@]+[>\]]\s?$")),
    ]

    terminal_stderr_re = [
        re.compile(to_bytes(r"% ?Unrecognized command")),
        re.compile(to_bytes(r"% ?Wrong parameter")),
        re.compile(to_bytes(r"% ?Incomplete command")),
        re.compile(to_bytes(r"% ?Ambiguous command")),
        re.compile(to_bytes(r"% ?Too many parameters")),
        re.compile(to_bytes(r"% ?Unavailable command")),
    ]

    terminal_config_prompt = re.compile(r"^\[.+\]$")

    def on_open_shell(self):
        # Disable output paging for the session so display commands do not
        # stop at "---- More ----". Best-effort: ignore if the account cannot.
        try:
            self._exec_cli_command(b"screen-length disable")
        except AnsibleConnectionFailure:
            pass
