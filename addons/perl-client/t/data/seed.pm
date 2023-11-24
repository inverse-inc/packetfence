package data::seed;

our %elements = (
    DHCP_Fingerprint => [{value => "1,2,3,4,5"}],
    DHCP_Vendor => [{value => "dhcp69-1.2.3.4"}],,
    User_Agent => [{value => "Mozilla/5.0 zPhone/4.2 IceFox/20.0"}, {value => "Unmatchable user agent"}],
    MAC_Vendor => [{mac => "012345", name => "Some MAC vendor"}],
    Device => [{name => "zPhone"}, {name => "dPhone"}, {name => "should never match"}],
    Combination => [
        {dhcp_fingerprint_id => "L1", dhcp_vendor_id => "L1", user_agent_id => "", mac_vendor_id => "L1", score => 5, device_id => "L1"},
        {dhcp_fingerprint_id => "L1", dhcp_vendor_id => "L1", user_agent_id => "L1", mac_vendor_id => "L1", score => 10, device_id => "L2"},
        {dhcp_fingerprint_id => "L1", dhcp_vendor_id => "L1", user_agent_id => "69", mac_vendor_id => "L1", score => 15, device_id => "L3"},
    ],
);

our %seed_data_ids = (
    WildcardMatchCombination => $elements{Combination}->[0],
    FullMatchCombination => $elements{Combination}->[1],
    MissMatchCombination => $elements{Combination}->[2],
    Valid_DHCP_Fingerprint => $elements{DHCP_Fingerprint}->[0],
    Valid_DHCP_Vendor => $elements{DHCP_Vendor}->[0],
    Valid_User_Agent => $elements{User_Agent}->[0],
    Valid_MAC_Vendor => $elements{MAC_Vendor}->[0],
    Valid_Device => $elements{Device}->[0],
    UnmatchableUser_Agent => $elements{User_Agent}->[1],
);

