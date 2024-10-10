Name:           packetfence-perl
Version:        1.2.4
Release:        1%{?dist}
Summary:        All modules loaded with cpan
BuildArch:      x86_64
AutoReq:        no
AutoProv:       yes

Group:          Applications
License:        GPL3
#URL:
Source0:        packetfence_perl_el_module_without_all_path.tar.gz

%description
All PacketFence required modules installed with cpan

%prep
%setup -q -c -T

%install
%{__rm} -rf %{buildroot}
%{__install} -d %{buildroot}/usr/local/pf/lib_perl

#mkdir -p /usr/local/pf/lib_perl
cd %{buildroot}/usr/local/pf/lib_perl
tar xzf %{S:0}

export PERL5LIB=/root/perl5/lib/perl5:/usr/local/pf/lib/lib_perl/lib/perl5/
export PKG_CONFIG_PATH=/usr/lib/pkgconfig/

%files
%dir    /usr/local/pf/lib_perl
        /usr/local/pf/lib_perl/*

%changelog
* Tue Jul 4 2024 Inverse <info@inverse.ca> 1.2.4-1
- Upgrade Template-Toolkit 3.009  -> 3.010
- Upgrade Sereal::Decoder 4.018 -> 5.004
- Upgrade Sereal::Encoder 4.018 -> 5.004
- Upgrade Crypt::OpenSSL::RSA 0.31 -> 0.33
- Upgrade Crypt::OpenSSL::X509 1.910 -> 1.914

* Thu Nov 16 2023 Inverse <info@inverse.ca> 1.2.3-1
- Add dependencies Digest-MD4 1.9

* Tue Nov 07 2023 Inverse <info@inverse.ca> 1.2.2-1
- Upgrade Net::HTTP 6.21 -> 6.23

* Wed Feb 23 2022 Inverse <info@inverse.ca> 1.2.1-1
- Add Test::Simple
   
* Tue Feb 08 2022 Inverse <info@inverse.ca> 1.2.0-1
- Add new dependencies and improve download from CPAN

* Wed Aug 25 2021 SupportInverse 1 <support@inverse.ca> 1.1.2-1
- Remove Crypt::OpenSSL::PKCS12

* Tue Aug 24 2021 SupportInverse 1 <support@inverse.ca> 1.1.1-1
- Remove Crypt::OpenSSL::PKCS12

* Wed Aug 11 2021 SupportInverse 1 <support@inverse.ca> 1.1.0-1
- Remove Crypt::SMIME

* Mon Jun 21 2021 SupportInverse 1 <support@inverse.ca> 0.1-1
- Initial spec
