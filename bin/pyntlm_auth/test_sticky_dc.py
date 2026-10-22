import importlib
import socket
import sys
import unittest
from unittest import mock

# Stub third-party modules that may be missing outside the ntlm-auth-api container,
# so the DC selection logic can be tested anywhere.
for _name in ('psutil', 'pytz', 'dns', 'dns.resolver',
              'samba', 'samba.credentials', 'samba.dcerpc', 'samba.dcerpc.misc',
              'samba.dcerpc.netlogon', 'samba.net'):
    try:
        importlib.import_module(_name)
    except ImportError:
        sys.modules[_name] = mock.MagicMock()

import global_vars
import rpc
import utils


class FakeNTSTATUSError(Exception):
    pass


def finddc_result(name):
    r = mock.Mock()
    r.pdc_dns_name = name
    return r


class TestParseStickyDc(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(utils.parse_sticky_dc(None), ['*'])
        self.assertEqual(utils.parse_sticky_dc(''), ['*'])
        self.assertEqual(utils.parse_sticky_dc('  *  '), ['*'])
        self.assertEqual(utils.parse_sticky_dc('dc1.example.com'), ['dc1.example.com'])
        self.assertEqual(utils.parse_sticky_dc(' dc1 , dc2 ,, * '), ['dc1', 'dc2', '*'])
        self.assertEqual(utils.parse_sticky_dc('dc1 dc2'), ['dc1', 'dc2'])


class TestFindDc(unittest.TestCase):
    def setUp(self):
        self.lp = mock.Mock()
        self.lp.get.return_value = 'EXAMPLE.COM'
        global_vars.c_dns_servers = '10.0.0.53'
        global_vars.c_server_name = 'ad.example.com'
        global_vars.c_ad_server = '10.0.0.10'
        global_vars.c_sticky_dc = ['*']
        self.net = mock.Mock()
        patchers = [
            mock.patch.object(rpc, 'Net', return_value=self.net),
            mock.patch.object(rpc, 'Credentials', mock.Mock()),
            mock.patch.object(rpc, 'NTSTATUSError', FakeNTSTATUSError),
            mock.patch.object(rpc.socket, 'gethostbyname', return_value='10.0.0.12'),
            mock.patch.object(rpc.config_generator, 'generate_hosts_entry'),
        ]
        mocks = []
        for p in patchers:
            mocks.append(p.start())
            self.addCleanup(p.stop)
        self.resolve, self.hosts_entry = mocks[3:]

    def finddc_by_address(self, answers):
        def finddc(**kwargs):
            if 'domain' in kwargs:
                return finddc_result('any-dc.example.com')
            answer = answers[kwargs['address']]
            if isinstance(answer, Exception):
                raise answer
            return finddc_result(answer)

        self.net.finddc.side_effect = finddc

    def called_kwargs(self):
        return [c[1] for c in self.net.finddc.call_args_list]

    def test_wildcard_uses_discovery_with_dns(self):
        self.finddc_by_address({})
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'any-dc.example.com'))
        self.assertEqual(self.called_kwargs()[0]['domain'], 'EXAMPLE.COM')

    def test_wildcard_uses_ad_fqdn_without_dns(self):
        global_vars.c_dns_servers = ''
        self.finddc_by_address({'10.0.0.10': 'dc0.example.com'})
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'dc0.example.com'))
        self.assertEqual(self.called_kwargs()[0]['address'], '10.0.0.10')

    def test_sticky_dc_pins_even_with_dns(self):
        global_vars.c_sticky_dc = ['10.0.0.12']
        self.finddc_by_address({'10.0.0.12': 'dc2.example.com'})
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'dc2.example.com'))
        self.assertEqual([k.get('address') for k in self.called_kwargs()], ['10.0.0.12'])

    def test_sticky_dc_list_failover(self):
        global_vars.c_sticky_dc = ['dc1', 'dc2']
        self.finddc_by_address({'dc1': FakeNTSTATUSError(0xc000005e, 'no logon servers'),
                                'dc2': 'dc2.example.com'})
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'dc2.example.com'))

    def test_sticky_dc_strict_when_all_fail(self):
        global_vars.c_sticky_dc = ['dc1', 'dc2']
        self.finddc_by_address({'dc1': FakeNTSTATUSError(1, 'down'), 'dc2': FakeNTSTATUSError(2, 'down too')})
        self.assertEqual(rpc.find_dc(self.lp), (2, 'down too', None))
        self.assertFalse(any('domain' in k for k in self.called_kwargs()))

    def test_sticky_dc_ip_adds_hosts_entry_when_name_unresolvable(self):
        global_vars.c_sticky_dc = ['10.0.0.12']
        self.finddc_by_address({'10.0.0.12': 'dc2.example.com'})
        self.resolve.side_effect = socket.gaierror('not found')
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'dc2.example.com'))
        self.hosts_entry.assert_called_once_with('10.0.0.12', 'dc2.example.com')

    def test_sticky_dc_ip_no_hosts_entry_when_name_resolvable(self):
        global_vars.c_sticky_dc = ['10.0.0.12']
        self.finddc_by_address({'10.0.0.12': 'dc2.example.com'})
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'dc2.example.com'))
        self.resolve.assert_called_once_with('dc2.example.com')
        self.hosts_entry.assert_not_called()

    def test_sticky_dc_fqdn_no_hosts_entry(self):
        global_vars.c_sticky_dc = ['dc2.example.com']
        self.finddc_by_address({'dc2.example.com': 'dc2.example.com'})
        self.resolve.side_effect = socket.gaierror('not found')
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'dc2.example.com'))
        self.resolve.assert_not_called()
        self.hosts_entry.assert_not_called()

    def test_sticky_dc_wildcard_fallback(self):
        global_vars.c_sticky_dc = ['dc1', '*']
        self.finddc_by_address({'dc1': FakeNTSTATUSError(1, 'down')})
        self.assertEqual(rpc.find_dc(self.lp), (0, '', 'any-dc.example.com'))


if __name__ == '__main__':
    unittest.main()
