%global     fb_prefix %{_prefix}/local/%{name}
Name:       fingerbank
Version:    4.3.2
Release:    1%{?dist}
BuildArch:  noarch
Summary:    An exhaustive device profiling tool
Packager:   Inverse inc. <support@inverse.ca>
Group:      System Environment/Daemons
License:    GPL
URL:        http://www.fingerbank.org/
Source0:    %{name}-%{version}.tar
BuildRoot:  %{_tmppath}/%{name}-root

Requires(post):     /sbin/chkconfig
Requires(preun):    /sbin/chkconfig

Requires(pre):      /usr/sbin/useradd, /usr/sbin/groupadd, /usr/bin/getent
Requires(postun):   /usr/sbin/userdel

Requires:   perl
Requires:   perl-version
Requires:   perl(Catalyst::Runtime)
Requires:   perl(aliased)
Requires:   perl(MooseX::Types::LoadableClass)
Requires:   perl(Catalyst::Plugin::Static::Simple)
Requires:   perl(Catalyst::Plugin::ConfigLoader)
Requires:   perl(Config::General)
Requires:   perl(Readonly)
Requires:   perl(Log::Log4perl)
Requires:   perl(Catalyst::Model::DBIC::Schema)
Requires:   perl(Catalyst::Action::REST)
Requires:   perl(DBD::SQLite)
Requires:   perl(LWP::Protocol::https)
Requires:   perl(MooseX::NonMoose)
Requires:   perl(SQL::Translator)
Requires:   perl(File::Touch)
Requires:   perl(LWP::Protocol::connect)
Requires:   perl(Data::OptList)
Requires:   fingerbank-collector >= 1.2.0
Requires:   sqlite

%description
Fingerbank

# Scriptlet that is executed just before the package is installed on the target system.
%pre
/usr/bin/getent group fingerbank || /usr/sbin/groupadd -r fingerbank
/usr/bin/getent passwd fingerbank || /usr/sbin/useradd -r -d /usr/local/fingerbank -s /sbin/nologin -g fingerbank fingerbank

%prep
%setup -q -n %{name}-%{version}

%build

%install
# /usr/local/fingerbank
%{__rm} -rf %{buildroot}
%{__install} -d %{buildroot}/usr/local/fingerbank
cp -r * %{buildroot}/usr/local/fingerbank
touch %{buildroot}/usr/local/fingerbank/logs/fingerbank.log

# Logrotate
%{__install} -D utils/fingerbank.logrotate %{buildroot}/etc/logrotate.d/fingerbank


# Scriptlet that is executed just after the package is installed on the target system.
%post
# Local database initialization
cd /usr/local/fingerbank/
make init-db-local

# Log file handling
if [ ! -e /usr/local/fingerbank/logs/fingerbank.log ]; then
    touch /usr/local/fingerbank/logs/fingerbank.log
fi

# fingerbank.conf empty file handling
if [ ! -f /usr/local/fingerbank/conf/fingerbank.conf ]; then
    echo "Creating non-existing 'fingerbank.conf' file"
    touch /usr/local/fingerbank/conf/fingerbank.conf
fi

if [ "$1" = "2"   ]; then
  # Execute all the scripts in the configuration upgrade directory
  /usr/local/fingerbank/conf/upgrade/*

  # Flush the Fingerbank cache if running with PacketFence
  if [ -f /usr/local/pf/bin/pfcmd ]; then 
    /usr/local/pf/bin/pfcmd cache fingerbank clear
    echo "Cleared the PacketFence Fingerbank cache"
  fi
fi

# applying / fixing permissions
make fixpermissions

%clean
rm -rf %{buildroot}


%postun


%files
%defattr(664,fingerbank,fingerbank,2775)
%dir                                /usr/local/fingerbank
/usr/local/fingerbank/*
%attr(775,fingerbank,fingerbank)    /usr/local/fingerbank/db/upgrade.pl
%attr(775,fingerbank,fingerbank)    /usr/local/fingerbank/conf/upgrade/*
%if 0%{?el6}
    %dir                            %{_sysconfdir}/logrotate.d
%endif
%config %attr(0644,root,root)       %{_sysconfdir}/logrotate.d/fingerbank
%ghost                              /usr/local/fingerbank/logs/fingerbank.log
%attr(664,fingerbank,fingerbank)    /usr/local/fingerbank/logs/fingerbank.log


%changelog
* Tue Aug 23 2022 Inverse Inc. <info@inverse.ca> - 4.3.2-1
- Adjust permissions detection for SQLite3 databases
* Thu Jun 16 2022 Inverse Inc. <info@inverse.ca> - 4.3.1-1
- Add function to list top device classes as objects
* Fri Apr 29 2022 Inverse Inc. <info@inverse.ca> - 4.3.0-1
- Support containers based PacketFence (v12)
* Mon Feb 14 2022 Inverse Inc. <info@inverse.ca> - 4.2.3-1
- Allow to add environment overrides to collector via the config
* Thu Jul 01 2021 Nicolas Quiniou-Briand <nqb@inverse.ca> - 4.2.2-1
- Use tar in place of git archive to get sources
* Wed Oct 23 2019 Inverse inc. <info@inverse.ca> - 4.1.5-1
- New upstream version
* Sun Jul 21 2019 Nicolas Quiniou-Briand <nqb@inverse.ca> - 4.1.4-2
- Update Packager and Source0 directives and remove package variable
* Sun Jul 21 2019 Nicolas Quiniou-Briand <nqb@inverse.ca> - 4.1.4-1
- Update package version to upstream version
* Fri Jun 28 2019 Nicolas Quiniou-Briand <nqb@inverse.ca> - 4.1.3-3
- Remove new vagrant directory from packaging
* Tue Apr 09 2019 Nicolas Quiniou-Briand <nqb@inverse.ca> - 4.1.3-2
- Adapt spec file to CI
