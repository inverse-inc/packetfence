Name:           cpan_perl_module
Version:        0.1
Release:        1%{?dist}
Summary:        All modules loaded with cpan
BuildArch:      x86_64
AutoReq:        no
AutoProv:       yes

Group:          Applications
License:        GPL3
#URL:
Source0:        cpan_perl_module_without_all_path.tar.gz

%description
All PakectFence requiered modules installed with cpan

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
%defattr(-, pf, pf)
%dir    /usr/local/pf/lib_perl
        /usr/local/pf/lib_perl/*

%changelog
* Mon Jun 20 2021 SupportInverse 1 <support@inverse.ca> 0.1-1
- Initial spec
