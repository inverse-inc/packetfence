use strict;
use warnings;

use 5.006;

package HTTP::BrowserDetect;

use vars qw(@ALL_TESTS);

# Operating Systems
our @OS_TESTS = qw(
    windows  mac     os2
    unix     linux   vms
    bsd      amiga
    bb10     rimtabletos
    chromeos ios
    firefoxos
);

# More precise Windows
our @WINDOWS_TESTS = qw(
    win16      win3x        win31
    win95      win98        winnt
    winme      win32        win2k
    winxp      win2k3       winvista
    win7       win8         win8_0
    win8_1     wince        winphone
    winphone7  winphone7_5  winphone8
);

# More precise Mac
our @MAC_TESTS = qw(
    macosx mac68k macppc
);

# More precise Unix
our @UNIX_TESTS = qw(
    sun     sun4     sun5
    suni86  irix     irix5
    irix6   hpux     hpux9
    hpux10  aix      aix1
    aix2    aix3     aix4
    sco     unixware mpras
    reliant dec      sinix
);

# More precise BSDs
our @BSD_TESTS = qw(
    freebsd
);

# Gaming devices
our @GAMING_TESTS = qw(
    ps3gameos pspgameos
);

# Device related tests
our @DEVICE_TESTS = qw(
    android audrey blackberry dsi iopener ipad
    iphone ipod kindle n3ds palm ps3 psp wap webos
    mobile tablet
);

# Browsers
our @BROWSER_TESTS = qw(
    mosaic        netscape    firefox
    chrome        safari      ie
    opera         lynx        links
    elinks        neoplanet   neoplanet2
    avantgo       emacs       mozilla
    konqueror     realplayer  netfront
    mobile_safari obigo       aol
    lotusnotes    staroffice  icab
    webtv
);

our @IE_TESTS = qw(
    ie3         ie4         ie4up
    ie5         ie5up       ie55
    ie55up      ie6         ie7
    ie8         ie9         ie10
    ie11
    ie_compat_mode
);

our @OPERA_TESTS = qw(
    opera3      opera4     opera5
    opera6      opera7
);

our @AOL_TESTS = qw(
    aol3        aol4
    aol5        aol6
);

our @NETSCAPE_TESTS = qw(
    nav2   nav3   nav4
    nav4up nav45  nav45up
    nav6   nav6up navgold
);

# Firefox variants
our @FIREFOX_TESTS = qw(
    firebird    iceweasel   phoenix
    namoroka
);

# Engine tests
our @ENGINE_TESTS = qw(
    gecko    trident
);

our @ROBOT_TESTS = qw(
    puf           curl           wget
    getright      robot          slurp
    yahoo         mj12bot        ahrefs
    altavista     lycos          infoseek
    lwp           webcrawler     linkexchange
    googlemobile  msn            msnmobile
    facebook      baidu          googleadsbot
    askjeeves     googleadsense  googlebotvideo
    googlebotnews googlebotimage google
    linkchecker   yandeximages   specialarchiver
    yandex
);

our @MISC_TESTS = qw(
    dotnet      x11
    java
);

push @ALL_TESTS,
    (
    @OS_TESTS,      @WINDOWS_TESTS,
    @MAC_TESTS,     @UNIX_TESTS,
    @BSD_TESTS,     @GAMING_TESTS,
    @DEVICE_TESTS,  @BROWSER_TESTS,
    @IE_TESTS,      @OPERA_TESTS,
    @AOL_TESTS,     @NETSCAPE_TESTS,
    @FIREFOX_TESTS, @ENGINE_TESTS,
    @ROBOT_TESTS,   @MISC_TESTS,
    );

sub _all_tests {
    return @ALL_TESTS;
}

# https://support.google.com/webmasters/answer/1061943?hl=en

my %ROBOT_NAMES = (
    ahrefs          => 'Ahrefs',
    altavista       => 'AltaVista',
    askjeeves       => 'AskJeeves',
    baidu           => 'Baidu Spider',
    curl            => 'curl',
    facebook        => 'Facebook',
    getright        => 'GetRight',
    google          => 'Google',
    googleadsbot    => 'Google AdsBot',
    googleadsense   => 'Google AdSense',
    googlebotimage  => 'Googlebot Images',
    googlebotnews   => 'Googlebot News',
    googlebotvideo  => 'Googlebot Video',
    googlemobile    => 'Google Mobile',
    infoseek        => 'InfoSeek',
    linkchecker     => 'LinkChecker',
    linkexchange    => 'LinkExchange',
    lwp             => 'LWP::UserAgent',
    lycos           => 'Lycos',
    mj12bot         => 'Majestic-12 DSearch',
    msn             => 'MSN',
    msnmobile       => 'MSN Mobile',
    puf             => 'puf',
    robot           => 'robot',
    slurp           => 'Yahoo! Slurp',
    specialarchiver => 'archive.org_bot',
    webcrawler      => 'WebCrawler',
    wget            => 'wget',
    yahoo           => 'Yahoo',
    yandex          => 'Yandex',
    yandeximages    => 'YandexImages',
);

my %BROWSER_NAMES = (
    aol           => 'AOL Browser',
    blackberry    => 'BlackBerry',
    chrome        => 'Chrome',
    curl          => 'curl',
    dsi           => 'Nintendo DSi',
    elinks        => 'ELinks',
    firefox       => 'Firefox',
    icab          => 'iCab',
    iceweasel     => 'IceWeasel',
    ie            => 'MSIE',
    links         => 'Links',
    lotusnotes    => 'Lotus Notes',
    lynx          => 'Lynx',
    mobile_safari => 'Mobile Safari',
    mosaic        => 'Mosaic',
    n3ds          => 'Nintendo 3DS',
    netfront      => 'NetFront',
    netscape      => 'Netscape',
    obigo         => 'Obigo',
    opera         => 'Opera',
    puf           => 'puf',
    realplayer    => 'RealPlayer',
    safari        => 'Safari',
    staroffice    => 'StarOffice',
    webtv         => 'WebTV',
);

# Device names
my %DEVICE_NAMES = (
    android    => 'Android',
    audrey     => 'Audrey',
    blackberry => 'BlackBerry',
    dsi        => 'Nintendo DSi',
    iopener    => 'iopener',
    ipad       => 'iPad',
    iphone     => 'iPhone',
    ipod       => 'iPod',
    kindle     => 'Amazon Kindle',
    n3ds       => 'Nintendo 3DS',
    palm       => 'Palm',
    ps3        => 'Sony PlayStation 3',
    psp        => 'Sony PlayStation Portable',
    wap        => 'WAP capable phone',
    webos      => 'webOS',
);

my %OS_NAMES = (
    android     => 'Android',
    bb10        => 'BlackBerry 10',
    chromeos    => 'Chrome OS',
    firefoxos   => 'Firefox OS',
    ios         => 'iOS',
    linux       => 'Linux',
    mac         => 'Mac',
    macosx      => 'Mac OS X',
    os2         => 'OS2',
    ps3gameos   => 'Playstation 3 GameOS',
    pspgameos   => 'Playstation Portable GameOS',
    rimtabletos => 'RIM Tablet OS',
    unix        => 'Unix',
    win2k       => 'Win2k',
    win2k3      => 'Win2k3',
    win3x       => 'Win3x',
    win7        => 'Win7',
    win8        => 'Win8',
    win8_0      => 'Win8',                          # FIXME bug compatibility
    win8_1      => 'Win8.1',
    win95       => 'Win95',
    win98       => 'Win98',
    winme       => 'WinME',
    winnt       => 'WinNT',
    winphone    => 'Windows Phone',
    winvista    => 'WinVista',
    winxp       => 'WinXP',
);

# Safari build -> version map for versions prior to 3.0
# (since then, version appears in the user-agent string)

my %safari_build_to_version = qw(
    48      0.8
    51      0.8.1
    60      0.8.2
    73      0.9
    74      1.0b2v74
    85      1.0
    85.7    1.0.2
    85.8    1.0.3
    100     1.1
    100.1   1.1.1
    125     1.2
    125.1   1.2.1
    125.7   1.2.2
    125.9   1.2.3
    125.11  1.2.4
    312     1.3
    312.3   1.3.1
    312.5   1.3.2
    412     2.0
    412.5   2.0.1
    416.12  2.0.2
    417.8   2.0.3
    419.3   2.0.4
);

#######################################################################################################
# BROWSER OBJECT

my $default = undef;

sub new {
    my ( $class, $user_agent ) = @_;

    my $self = {};
    bless $self, $class;

    unless ( defined $user_agent ) {
        $user_agent = $ENV{'HTTP_USER_AGENT'};
    }

    $self->user_agent($user_agent);
    return $self;
}

### Accessors for computed-on-demand test attributes

foreach my $test ( @ENGINE_TESTS, @MISC_TESTS ) {
    no strict 'refs';
    my $key = uc $test;
    *{$test} = sub {
        my ($self) = @_;
        return $self->{tests}->{$key} || 0;
    };
}

foreach my $test (
    @OS_TESTS,  @WINDOWS_TESTS, @MAC_TESTS, @UNIX_TESTS,
    @BSD_TESTS, @GAMING_TESTS
    ) {
    no strict 'refs';
    my $key = uc $test;
    *{$test} = sub {
        my ($self) = @_;
        $self->_init_os() unless $self->{os_tests};
        return $self->{os_tests}->{$key} || 0;
    };
}

foreach my $test ( @BROWSER_TESTS, @FIREFOX_TESTS ) {
    no strict 'refs';
    my $key = uc $test;
    *{$test} = sub {
        my ($self) = @_;
        return $self->{browser_tests}->{$key} || 0;
    };
}

foreach my $test (@ROBOT_TESTS) {
    no strict 'refs';
    my $key = uc $test;
    *{$test} = sub {
        my ($self) = @_;
        $self->_init_robots() unless $self->{robot_tests};
        return $self->{robot_tests}->{$key} || 0;
    };
}

foreach my $test (
    @NETSCAPE_TESTS, @IE_TESTS, @AOL_TESTS,
    @OPERA_TESTS
    ) {
    no strict 'refs';
    my $key = uc $test;
    *{$test} = sub {
        my ($self) = @_;
        $self->_init_version() unless $self->{version_tests};
        return $self->{version_tests}->{$key} || 0;
    };
}

foreach my $test (@DEVICE_TESTS) {
    no strict 'refs';
    my $key = uc $test;
    *{$test} = sub {
        my ($self) = @_;
        $self->_init_device() unless $self->{device_tests};
        return $self->{device_tests}->{$key} || 0;
    };
}

sub user_agent {
    my ( $self, $user_agent ) = @_;
    if ( defined $user_agent ) {
        $self->{user_agent} = $user_agent;
        $self->_init_core();
    }
    return $self->{user_agent};
}

### This is code for setting up $self based on a new
### user-agent. Browser and engine tests always get run right away.

# Private method -- Set up the basics (browser and misc attributes)
# for a new user-agent string
sub _init_core {
    my ($self) = @_;

    # Reset versions, this gets filled in on demand in _init_version
    delete $self->{version_tests};
    delete $self->{major};
    delete $self->{minor};
    delete $self->{beta};
    delete $self->{realplayer_version};

    # Reset OS tests, this gets filled in on demand in _init_os
    delete $self->{cached_os};
    delete $self->{os_tests};

    # Reset device info, this gets filled in on demand in _init_device
    delete $self->{device_tests};
    delete $self->{device};
    delete $self->{device_name};

    # Reset robot info, this gets filled in on demand in _init_robots
    delete $self->{robot_tests};
    delete $self->{robot_name};

    # These get filled in immediately
    $self->{tests}         = {};
    $self->{browser_tests} = {};

    my $tests         = $self->{tests};
    my $browser_tests = $self->{browser_tests};
    my $browser       = undef;

    my $ua = lc $self->{user_agent};

    # Detect engine
    $self->{engine_version} = undef;

    $tests->{TRIDENT} = ( index( $ua, "trident/" ) != -1 );
    if ( $tests->{TRIDENT} && $ua =~ /trident\/([\w\.\d]*)/ ) {
        $self->{engine_version} = $1;
    }

    $self->{gecko_version} = undef;
    if ( index( $ua, "gecko" ) != -1 && index( $ua, "like gecko" ) == -1 ) {
        $tests->{GECKO} = 1;
        if ( $ua =~ /\([^)]*rv:([\w.\d]*)/ ) {
            $self->{gecko_version}  = $1;
            $self->{engine_version} = $1;
        }
    }

    # Detect browser

    if (
        $ua =~ m{
                (firebird|iceweasel|phoenix|namoroka|firefox)
                \/
                ( [^.]* )           # Major version number is everything before first dot
                \.                  # The first dot
                ( [\d]* )           # Minor version nnumber is digits after first dot
            }xo
        && index( $ua, "not firefox" ) == -1
        )    # Hack for Yahoo Slurp
    {
        # Browser is Firefox, possibly under an alternate name

        if ( $1 eq 'iceweasel' ) {    # FIXME - bug compatibility?
            $browser = 'ICEWEASEL';
        }
        else {
            $browser = 'FIREFOX';
        }
        $browser_tests->{ uc $1 } = 1;
        $browser_tests->{'FIREFOX'} = 1;
    }
    elsif ( $ua =~ m{opera|opr\/} ) {

        # Browser is Opera

        $browser = 'OPERA';
        $browser_tests->{OPERA} = 1;
    }
    elsif ($tests->{TRIDENT}
        || index( $ua, "msie" ) != -1
        || index( $ua, 'microsoft internet explorer' ) != -1 ) {

        # Browser is MSIE (possibly AOL branded)

        $browser_tests->{IE} = 1;

        if (
            index( $ua, "aol" ) == -1    # FIXME - bug compatibility?
            && index( $ua, "america online browser" ) == -1
            ) {
            $browser = 'IE';
        }
        else {
            $browser = 'AOL';
            $browser_tests->{AOL} = 1;
        }
    }
    elsif ( index( $ua, "chrome/" ) != -1 ) {

        # Browser is Chrome

        $browser = 'CHROME';
        $browser_tests->{CHROME} = 1;
    }
    elsif (index( $ua, "blackberry" ) != -1
        || index( $ua, "bb10" ) != -1
        || index( $ua, "rim tablet os" ) != -1 ) {

        # Needs to go above the Safari check
        $browser = 'BLACKBERRY';    # Test gets set during device check

        # FIXME bug compatibility?
        $browser_tests->{SAFARI} = 1
            if index( $ua, "safari" ) != -1
            || index( $ua, "applewebkit" ) != -1;
        $browser_tests->{MOBILE_SAFARI} = 1
            if index( $ua, "mobile safari" ) != -1;
    }
    elsif (( index( $ua, "safari" ) != -1 )
        || ( index( $ua, "applewebkit" ) != -1 ) ) {

        # Browser is Safari

        $browser_tests->{SAFARI} = 1;
        if ( index( $ua, " mobile safari/" ) == -1 ) {
            $browser = 'SAFARI';
        }
        else {
            $browser = 'MOBILE_SAFARI';
            $browser_tests->{MOBILE_SAFARI} = 1;
        }
    }
    elsif (!$tests->{TRIDENT}
        && index( $ua, "mozilla" ) != -1
        && index( $ua, "msie" ) == -1
        && index( $ua, "spoofer" ) == -1
        && index( $ua, "compatible" ) == -1
        && index( $ua, "webtv" ) == -1
        && index( $ua, "hotjava" ) == -1
        && index( $ua, "nintendo" ) == -1
        && index( $ua, "playstation 3" ) == -1
        && index( $ua, "playstation portable" ) == -1
        && index( $ua, "browsex" ) == -1 ) {

        # Browser is a Gecko-powered Netscape (i.e. Mozilla) version

        $browser                   = 'NETSCAPE';
        $browser_tests->{NETSCAPE} = 1;
        $browser_tests->{MOZILLA}  = ( $tests->{GECKO} );
    }
    elsif ( index( $ua, "neoplanet" ) != -1 ) {

        # Browser is Neoplanet

        $browser = undef;
        $browser_tests->{NEOPLANET} = 1;
        $browser_tests->{NEOPLANET2} = 1 if ( index( $ua, "2." ) != -1 );
    }

    ## Long series of unlikely browsers
    elsif ( index( $ua, "staroffice" ) != -1 ) {
        $browser = 'STAROFFICE';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "icab" ) != -1 ) {
        $browser = 'ICAB';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "lotus-notes" ) != -1 ) {
        $browser = 'LOTUSNOTES';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "konqueror" ) != -1 ) {
        $browser = 'KONQUEROR';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "lynx" ) != -1 ) {
        $browser = 'LYNX';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "elinks" ) != -1 ) {
        $browser                   = 'ELINKS';
        $browser_tests->{$browser} = 1;
        $browser_tests->{LINKS}    = 1;          # FIXME bug compatibility
    }
    elsif ( index( $ua, "links" ) != -1 ) {
        $browser = 'LINKS';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "webtv" ) != -1 ) {
        $browser = 'WEBTV';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "mosaic" ) != -1 ) {
        $browser = 'MOSAIC';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, 'emacs' ) != -1 ) {
        $browser = 'EMACS';
        $browser_tests->{$browser} = 1;
    }
    elsif (index( $ua, "playstation 3" ) != -1
        || index( $ua, "playstation portable" ) != -1
        || index( $ua, "netfront" ) != -1 ) {
        $browser = 'NETFRONT';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "nintendo 3ds" ) != -1 ) {
        $browser = 'N3DS';    # Test gets set during device check
    }
    elsif ( index( $ua, "nintendo dsi" ) != -1 ) {
        $browser = 'DSI';     # Test gets set during device check
    }
    elsif ( index( $ua, "obigo/" ) != -1 ) {
        $browser = 'OBIGO';
        $browser_tests->{$browser} = 1;
    }
    elsif ( index( $ua, "libcurl" ) != -1 ) {
        $browser = 'CURL';    # Test gets set during robot check
    }
    elsif ( index( $ua, "puf/" ) != -1 ) {
        $browser = 'PUF';     # Test gets set during robot check
    }

    $self->{browser} = $browser;

    # Other random tests

    $tests->{JAVA} = 1
        if ( index( $ua, "java" ) != -1
        || index( $ua, "jdk" ) != -1
        || index( $ua, "jakarta commons-httpclient" ) != -1 );
    $tests->{X11}    = 1 if index( $ua, "x11" ) != -1;
    $tests->{DOTNET} = 1 if index( $ua, ".net clr" ) != -1;

    if ( index( $ua, "realplayer" ) != -1 ) {

        # Hack for Realplayer -- fix the version and "real" browser

        $self->_init_version;  # Set appropriate tests for whatever the "real"
                               # browser is.

        # Now set the browser to Realplayer.
        $self->{browser}             = 'REALPLAYER';
        $browser_tests->{REALPLAYER} = 1;

        # Now override the version with the Realplayer version (but leave
        # alone the tests we already set, which might have been based on the
        # "real" browser's version).
        $self->{realplayer_version} = undef;

        if ( $ua =~ /realplayer\/([\d+\.]+)/ ) {
            $self->{realplayer_version} = $1;
            ( $self->{major}, $self->{minor} )
                = split( /\./, $self->{realplayer_version} );
            $self->{minor} = ".$self->{minor}" if defined( $self->{minor} );
        }
        elsif ( $ua =~ /realplayer\s(\w+)/ ) {
            $self->{realplayer_version} = $1;
        }
    }

    if ( index( $ua, "(r1 " ) != -1 ) {

        # Realplayer plugin -- don't override browser but do set property
        $browser_tests->{REALPLAYER} = 1;
    }
}

sub _init_robots {
    my $self = shift;

    my $ua            = lc $self->{user_agent};
    my $tests         = $self->{tests};
    my $browser_tests = $self->{browser_tests};

    my $robot_tests = $self->{robot_tests} = {};
    my $r = undef;

    if ( index( $ua, "libwww-perl" ) != -1 || index( $ua, "lwp-" ) != -1 ) {
        $r = 'LWP';
    }
    elsif ( index( $ua, "slurp" ) != -1 ) {
        $r = 'SLURP';
        $robot_tests->{YAHOO} = 1;
    }
    elsif (index( $ua, "yahoo" ) != -1
        && index( $ua, 'jp.co.yahoo.android' ) == -1 ) {
        $r = 'YAHOO';
    }
    elsif (index( $ua, "msnbot-mobile" ) != -1
        || index( $ua, "bingbot-mobile" ) != -1 ) {
        $r = 'MSNMOBILE';
        $robot_tests->{MSN} = 1;
    }
    elsif ( index( $ua, "msnbot" ) != -1 || index( $ua, "bingbot" ) != -1 ) {
        $r = 'MSN';
    }
    elsif ( index( $ua, "ahrefsbot" ) != -1 ) {
        $r = 'AHREFS';
    }
    elsif ( index( $ua, "altavista" ) != -1 ) {
        $r = 'ALTAVISTA';
    }
    elsif ( index( $ua, "ask jeeves/teoma" ) != -1 ) {
        $r = 'ASKJEEVES';
    }
    elsif ( index( $ua, "baiduspider" ) != -1 ) {
        $r = 'BAIDU';
    }
    elsif ( index( $ua, "libcurl" ) != -1 ) {
        $r = 'CURL';
    }
    elsif ( index( $ua, "facebookexternalhit" ) != -1 ) {
        $r = 'FACEBOOK';
    }
    elsif ( index( $ua, "getright" ) != -1 ) {
        $r = 'GETRIGHT';
    }
    elsif ( index( $ua, "adsbot-google" ) != -1 ) {
        $r = 'GOOGLEADSBOT';
    }
    elsif ( index( $ua, "mediapartners-google" ) != -1 ) {
        $r = 'GOOGLEADSENSE';
    }
    elsif ( index( $ua, "googlebot-image" ) != -1 ) {
        $r = 'GOOGLEBOTIMAGE';
        $robot_tests->{GOOGLE} = 1;
    }
    elsif ( index( $ua, "googlebot-news" ) != -1 ) {
        $r = 'GOOGLEBOTNEWS';
        $robot_tests->{GOOGLE} = 1;
    }
    elsif ( index( $ua, "googlebot-video" ) != -1 ) {
        $r = 'GOOGLEBOTVIDEO';
        $robot_tests->{GOOGLE} = 1;
    }
    elsif ( index( $ua, "googlebot-mobile" ) != -1 ) {
        $r = 'GOOGLEMOBILE';
        $robot_tests->{GOOGLE} = 1;
    }
    elsif ( index( $ua, "googlebot" ) != -1 ) {
        $r = 'GOOGLE';
    }
    elsif ( index( $ua, "infoseek" ) != -1 ) {
        $r = 'INFOSEEK';
    }
    elsif ( index( $ua, "lecodechecker" ) != -1 ) {
        $r = 'LINKEXCHANGE';
    }
    elsif ( index( $ua, "linkchecker" ) != -1 ) {
        $r = 'LINKCHECKER';
    }
    elsif ( index( $ua, "lycos" ) != -1 ) {
        $r = 'LYCOS';
    }
    elsif ( index( $ua, "mj12bot/" ) != -1 ) {
        $r = 'MJ12BOT';
    }
    elsif ( index( $ua, "puf/" ) != -1 ) {
        $r = 'PUF';
    }
    elsif ( index( $ua, "scooter" ) != -1 ) {
        $r = 'SCOOTER';
    }
    elsif ( index( $ua, "special_archiver" ) != -1 ) {
        $r = 'SPECIALARCHIVER';
    }
    elsif ( index( $ua, "webcrawler" ) != -1 ) {
        $r = 'WEBCRAWLER';
    }
    elsif ( index( $ua, "wget" ) != -1 ) {
        $r = 'WGET';
    }
    elsif ( index( $ua, "yandexbot" ) != -1 ) {
        $r = 'YANDEX';
    }
    elsif ( index( $ua, "yandeximages" ) != -1 ) {
        $r = 'YANDEXIMAGES';
    }

    if ($r) {
        $robot_tests->{$r} = 1;
        $self->{robot_name} = $ROBOT_NAMES{ lc $r };    # Including undef
    }

    $robot_tests->{ROBOT}
        ||= $r
        || $tests->{JAVA}
        || index( $ua, "agent" ) != -1
        || index( $ua, "bot" ) != -1
        || index( $ua, "copy" ) != -1
        || index( $ua, "crawl" ) != -1
        || index( $ua, "fetch" ) != -1
        || index( $ua, "find" ) != -1
        || index( $ua, "ia_archive" ) != -1
        || index( $ua, "index" ) != -1
        || index( $ua, "reap" ) != -1
        || index( $ua, "spider" ) != -1
        || index( $ua, "worm" ) != -1
        || index( $ua, "zyborg" ) != -1
        || $ua =~ /seek (?! mo (?: toolbar )? \s+ \d+\.\d+ )/x
        || $ua =~ /search (?! [\w\s]* toolbar \b | bar \b )/x;
}

### OS tests, only run on demand

sub _init_os {
    my $self = shift;

    my $tests         = $self->{tests};
    my $browser_tests = $self->{browser_tests};
    my $ua            = lc $self->{user_agent};

    my $os_tests = $self->{os_tests} = {};
    my $os = undef;

    # Windows

    if ( index( $ua, "16bit" ) != -1 ) {
        $os = 'WIN16';
        $os_tests->{WIN16} = $os_tests->{WINDOWS} = 1;
    }

    if ( index( $ua, "win" ) != -1 ) {
        if (   index( $ua, "win16" ) != -1
            || index( $ua, "windows 3" ) != -1
            || index( $ua, "windows 16-bit" ) != -1 ) {
            $os_tests->{WIN16} = 1;
            $os_tests->{WIN3X} = 1;
            $os_tests->{WIN31} = 1 if index( $ua, "windows 3.1" ) != -1;
            $os                = "WIN3X";
        }
        elsif (index( $ua, "win95" ) != -1
            || index( $ua, "windows 95" ) != -1 ) {
            $os = "WIN95";
            $os_tests->{$os} = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "win 9x 4.90" ) != -1 )    # whatever
        {
            $os = "WINME";
            $os_tests->{$os} = $os_tests->{WIN32} = 1;
        }
        elsif (index( $ua, "win98" ) != -1
            || index( $ua, "windows 98" ) != -1 ) {
            $os = "WIN98";
            $os_tests->{$os} = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "windows ce" ) != -1 ) {
            $os = 'WINCE';
            $os_tests->{WINCE} = 1;
        }
        elsif ( index( $ua, "windows phone" ) != -1 ) {
            $os = 'WINPHONE';
            $os_tests->{WINPHONE} = 1;

            $os_tests->{WINPHONE7} = 1
                if index( $ua, "windows phone os 7.0" ) != -1;
            $os_tests->{WINPHONE7_5} = 1
                if index( $ua, "windows phone os 7.5" ) != -1;
            $os_tests->{WINPHONE8} = 1
                if index( $ua, "windows phone 8.0" ) != -1;
        }
    }

    if ( index( $ua, "nt" ) != -1 ) {
        if ( index( $ua, "nt 5.0" ) != -1 || index( $ua, "nt5" ) != -1 ) {
            $os = "WIN2K";
            $os_tests->{$os} = $os_tests->{WINNT} = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "nt 5.1" ) != -1 ) {
            $os = "WINXP";
            $os_tests->{$os} = $os_tests->{WINNT} = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "nt 5.2" ) != -1 ) {
            $os = "WIN2K3";
            $os_tests->{$os} = $os_tests->{WINNT} = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "nt 6.0" ) != -1 ) {
            $os = "WINVISTA";
            $os_tests->{$os} = $os_tests->{WINNT} = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "nt 6.1" ) != -1 ) {
            $os = "WIN7";
            $os_tests->{$os} = $os_tests->{WINNT} = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "nt 6.2" ) != -1 ) {
            $os = "WIN8_0";
            $os_tests->{$os} = $os_tests->{WIN8} = $os_tests->{WINNT}
                = $os_tests->{WIN32} = 1;
        }
        elsif ( index( $ua, "nt 6.3" ) != -1 ) {
            $os = "WIN8_1";
            $os_tests->{$os} = $os_tests->{WIN8} = $os_tests->{WINNT}
                = $os_tests->{WIN32} = 1;
        }
        elsif (index( $ua, "winnt" ) != -1
            || index( $ua, "windows nt" ) != -1
            || index( $ua, "nt4" ) != -1
            || index( $ua, "nt3" ) != -1 ) {
            $os = "WINNT";
            $os_tests->{$os} = $os_tests->{WIN32} = 1;
        }
    }

    if ($os) {

        # Windows, set through some path above
        $os_tests->{WINDOWS} = 1;
        $os_tests->{WIN32} = 1 if index( $ua, "win32" ) != -1;
    }
    elsif ( index( $ua, "macintosh" ) != -1 || index( $ua, "mac_" ) != -1 ) {

        # Mac operating systems
        $os_tests->{MAC} = 1;
        if ( index( $ua, "mac os x" ) != -1 ) {
            $os = "MACOSX";
            $os_tests->{$os} = 1;
        }
        else {
            $os = "MAC";
        }
        if ( index( $ua, "68k" ) != -1 || index( $ua, "68000" ) != -1 ) {
            $os_tests->{MAC68K} = 1;
        }
        elsif ( index( $ua, "ppc" ) != -1 || index( $ua, "powerpc" ) != -1 ) {
            $os_tests->{MACPPC} = 1;
        }
    }
    elsif (index( $ua, "ipod" ) != -1
        || index( $ua, "iphone" ) != -1
        || index( $ua, "ipad" ) != -1 ) {

        # iOS
        $os = 'IOS';
        $os_tests->{$os} = 1;
    }
    elsif ( index( $ua, "android" ) != -1 ) {

        # Android
        $os = 'ANDROID';    # Test gets set in the device testing
                            # FIXME bug compatibility:
        $os_tests->{LINUX} = $os_tests->{UNIX} = 1
            if index( $ua, "inux" ) != -1;
    }
    elsif ( index( $ua, "inux" ) != -1 ) {

        # Linux
        $os = 'LINUX';
        $os_tests->{LINUX} = $os_tests->{UNIX} = 1;
    }
    elsif ( $tests->{X11} && index( $ua, "cros" ) != -1 ) {

        # ChromeOS
        $os = 'CHROMEOS';
        $os_tests->{CHROMEOS} = 1;
    }
    ## Long series of unlikely OSs
    elsif ( index( $ua, 'amiga' ) != -1 ) {
        $os = 'AMIGA';
        $os_tests->{$os} = 1;
    }
    elsif ( index( $ua, 'os/2' ) != -1 ) {
        $os = 'OS2';
        $os_tests->{$os} = 1;
    }
    elsif ( index( $ua, "samsung" ) == -1 && index( $ua, "sun" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{SUN} = $os_tests->{UNIX} = 1;
        $os_tests->{SUNI86} = 1 if index( $ua, "i86" ) != -1;
        $os_tests->{SUN4}   = 1 if index( $ua, "sunos 4" ) != -1;
        $os_tests->{SUN5}   = 1 if index( $ua, "sunos 5" ) != -1;
    }
    elsif ( index( $ua, "irix" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{IRIX} = $os_tests->{UNIX} = 1;
        $os_tests->{IRIX5} = 1 if ( index( $ua, "irix5" ) != -1 );
        $os_tests->{IRIX6} = 1 if ( index( $ua, "irix6" ) != -1 );
    }
    elsif ( index( $ua, "hp-ux" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{HPUX} = $os_tests->{UNIX} = 1;
        $os_tests->{HPUX9}  = 1 if index( $ua, "09." ) != -1;
        $os_tests->{HPUX10} = 1 if index( $ua, "10." ) != -1;
    }
    elsif ( index( $ua, "aix" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{AIX} = $os_tests->{UNIX} = 1;
        $os_tests->{AIX1} = 1 if ( index( $ua, "aix 1" ) != -1 );
        $os_tests->{AIX2} = 1 if ( index( $ua, "aix 2" ) != -1 );
        $os_tests->{AIX3} = 1 if ( index( $ua, "aix 3" ) != -1 );
        $os_tests->{AIX4} = 1 if ( index( $ua, "aix 4" ) != -1 );
    }
    elsif ( index( $ua, "sco" ) != -1 || index( $ua, "unix_sv" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{SCO} = $os_tests->{UNIX} = 1;
    }
    elsif ( index( $ua, "unix_system_v" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{UNIXWARE} = $os_tests->{UNIX} = 1;
    }
    elsif ( index( $ua, "ncr" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{MPRAS} = $os_tests->{UNIX} = 1;
    }
    elsif ( index( $ua, "reliantunix" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{RELIANT} = $os_tests->{UNIX} = 1;
    }
    elsif (index( $ua, "dec" ) != -1
        || index( $ua, "osf1" ) != -1
        || index( $ua, "declpha" ) != -1
        || index( $ua, "alphaserver" ) != -1
        || index( $ua, "ultrix" ) != -1
        || index( $ua, "alphastation" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{DEC} = $os_tests->{UNIX} = 1;
    }
    elsif ( index( $ua, "sinix" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{SINIX} = $os_tests->{UNIX} = 1;
    }
    elsif ( index( $ua, "bsd" ) != -1 ) {
        $os = 'UNIX';
        $os_tests->{BSD} = $os_tests->{UNIX} = 1;
        $os_tests->{FREEBSD} = 1 if index( $ua, "freebsd" ) != -1;
    }
    elsif ( $tests->{X11} ) {

        # Some Unix we didn't identify
        $os = 'UNIX';
        $os_tests->{UNIX} = 1;
    }
    elsif ( index( $ua, "vax" ) != -1 || index( $ua, "openvms" ) != -1 ) {

        # FIXME - what about $os?
        $os_tests->{VMS} = 1;
    }
    elsif ( index( $ua, "bb10" ) != -1 ) {
        $os = 'BB10';
        $os_tests->{BB10} = 1;
    }
    elsif ( index( $ua, "rim tablet os" ) != -1 ) {
        $os = 'RIMTABLETOS';
        $os_tests->{RIMTABLETOS} = 1;
    }
    elsif ( index( $ua, "playstation 3" ) != -1 ) {
        $os = 'PS3GAMEOS';
        $os_tests->{PS3GAMEOS} = 1;
    }
    elsif ( index( $ua, "playstation portable" ) != -1 ) {
        $os = 'PSPGAMEOS';
        $os_tests->{PSPGAMEOS} = 1;
    }
    elsif ( index( $ua, "windows" ) != -1 ) {

        # Windows again, the super generic version
        $os_tests->{WINDOWS} = 1;
    }
    elsif ( index( $ua, "win32" ) != -1 ) {
        $os_tests->{WIN32} = $os_tests->{WINDOWS} = 1;
    }
    else {
        $os = undef;
    }

    # To deal with FirefoxOS we seem to have to load-on-demand devices
    # also, by calling ->mobile and ->tablet. We have to be careful;
    # if we ever created a loop back from _init_devices to _init_os
    # we'd run forever.
    if (  !$os
        && $browser_tests->{FIREFOX}
        && index( $ua, "fennec" ) == -1
        && ( $self->mobile || $self->tablet ) ) {
        $os = 'FIREFOXOS';
        $os_tests->{FIREFOXOS} = 1;
    }

    $self->{cached_os} = $os ? lc $os : undef;
}

### Version determination, only run on demand

sub _init_version {
    my ($self) = @_;

    my $ua            = lc $self->{user_agent};
    my $tests         = $self->{tests};
    my $browser_tests = $self->{browser_tests};
    my $browser       = $self->{browser};

    $self->{version_tests} = {};
    my $version_tests = $self->{version_tests};

    my ( $major, $minor, $beta );

    ### First figure out version numbers. We try the regexp that makes the most
    ### sense for whatever browser we have, and if that doesn't work
    ### we fall back to increasingly generic methods.

    if ( defined($browser) && $browser eq 'OPERA' ) {

        # Opera has a "compatible; " section, but lies sometimes. It needs
        # special handling.

        # http://dev.opera.com/articles/view/opera-ua-string-changes/
        # http://my.opera.com/community/openweb/idopera/
        # Opera/9.80 (S60; SymbOS; Opera Mobi/320; U; sv) Presto/2.4.15 Version/10.00
        # Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.52 Safari/537.36 OPR/15.0.1147.100

        if ( $ua =~ m{\AOpera.*\sVersion/(\d*)\.(\d*)\z}i ) {
            $major = $1;
            $minor = $2;
        }
        elsif ( $ua =~ m{\bOPR/(\d+)\.(\d+)}i ) {
            $major = $1;
            $minor = $2;
        }
        elsif ( $ua =~ m{Opera[ /](\d+).(\d+)}i ) {
            $major = $1;
            $minor = $2;
        }
    }
    elsif ( $ua
        =~ m{\b compatible; \s* [\w\-]* [/\s] ( [0-9]+ ) (?: .([0-9]+) (\S*) )? ;}x
        ) {
        # MSIE and some others use a "compatible" format
        ( $major, $minor, $beta ) = ( $1, $2, $3 );
    }
    elsif ( !$browser ) {

        # Nothing else is going to work if $browser isn't defined; skip the
        # specific approaches and go straight to the generic ones.
    }
    elsif ( $browser_tests->{CHROME} ) {

        # Chrome Version

        ( $major, $minor, $beta ) = (
            $ua =~ m{
                chrome
                \/
                ( \d+ )        # Major version number
                (?:\.( \d+ ))? # Minor version number follows first dot
                ([0-9\.]*)     # Beta is all other dots and digits
            }x
        );

    }
    elsif ( $browser_tests->{SAFARI} ) {

        # Safari Version

        if (
            0
            && $ua =~ m{ # Disabled for bug compatibility
                version/
                ( \d+ )       # Major version number is everything before first dot
                \.            # First dot
                ( \d+ )?      # Minor version number follows dot
            }x
            ) {
            # Safari starting with version 3.0 provides its own public version
            ( $major, $minor ) = ( $1, $2, undef );
        }
        elsif ( $ua =~ m{ safari/ ( \d+ (?: \.\d+ )* ) }x ) {
            if ( my ( $safari_build, $safari_minor ) = split /\./, $1 ) {
                $major = int( $safari_build / 100 );
                $minor = int( $safari_build % 100 );
                $beta  = ".$safari_minor" if $safari_minor;
            }
        }
        elsif ( $ua =~ m{applewebkit\/([\d\.]{1,})}xi ) {
            if ( my ( $safari_build, $safari_minor ) = split /\./, $1 ) {
                $major = int( $safari_build / 100 );
                $minor = int( $safari_build % 100 );
                $beta  = ".$safari_minor" if $safari_minor;
            }
        }
    }
    elsif ( $browser_tests->{FIREFOX} || $browser_tests->{NETSCAPE} ) {

        # Firefox or some variant

        ( $major, $minor, $beta ) = $ua =~ m{
                (?:netscape6?|firefox|firebird|iceweasel|phoenix|namoroka)\/
                ( [^.]* ) # Major version number is everything before first dot
                \.       # The first dot
                ( [\d]* ) # Minor version number is digits after first dot
                ( [^\s]* )
            }x;
    }
    elsif ( $browser_tests->{IE} ) {

        # MSIE

        if ( $ua =~ m{\b msie \s ( [0-9\.]+ ) (?: [a-z]+ [a-z0-9]* )? ;}x ) {

            # Internet Explorer
            ( $major, $minor, $beta ) = split /\./, $1;
        }
        elsif ( $ua =~ m{\b rv: ( [0-9\.]+ ) \b}x ) {

            # MSIE masking as Gecko really well ;)
            ( $major, $minor, $beta ) = split /\./, $1;
        }
    }
    elsif ( $browser eq 'NETFRONT' ) {
        if ( $ua =~ m{NetFront/(\d*)\.(\d*) Kindle}i ) {
            $major = $1;
            $minor = $2;
        }
    }
    elsif ( $browser eq 'N3DS' ) {
        if ( $ua =~ m{Nintendo 3DS;.*\sVersion/(\d*)\.(\d*)}i ) {
            $major = $1;
            $minor = $2;
        }
    }

    if ( !defined($major) ) {

        # We still don't have a version. Try a generic approach.

        ( $major, $minor, $beta ) = (
            $ua =~ m{
                \S+        # Greedily catch anything leading up to forward slash.
                \/                # Version starts with a slash
                [A-Za-z]*         # Eat any letters before the major version
                ( [0-9]+ )        # Major version number is everything before the first dot
                 \.               # The first dot
                ([\d]* )          # Minor version number is every digit after the first dot
                                  # Throw away remaining numbers and dots
                ( [^\s]* )        # Beta version string is up to next space
            }x
        );
    }

    if ( !defined($major) ) {

        # We still don't have one. More generic.
        if ( $ua =~ /[A-Za-z]+\/(\d+)\;/ ) {
            $major = $1;
            $minor = 0;
        }
    }

    # Oh well.
    $major = 0     if !$major;
    $minor = 0     if !$minor;
    $beta  = undef if ( defined($beta) && $beta eq '' );

    # Now set version tests

    if ( $browser_tests->{NETSCAPE} ) {

        # Netscape browsers
        $version_tests->{NAV2}   = 1 if $major == 2;
        $version_tests->{NAV3}   = 1 if $major == 3;
        $version_tests->{NAV4}   = 1 if $major == 4;
        $version_tests->{NAV4UP} = 1 if $major >= 4;
        $version_tests->{NAV45}  = 1 if $major == 4 && $minor == 5;
        $version_tests->{NAV45UP} = 1
            if ( $major == 4 && ".$minor" >= .5 )
            || $major >= 5;
        $version_tests->{NAVGOLD} = 1
            if defined($beta) && ( index( $beta, "gold" ) != -1 );
        $version_tests->{NAV6} = 1
            if ( $major == 5 || $major == 6 );    # go figure
        $version_tests->{NAV6UP} = 1 if $major >= 5;
    }

    if ( $browser_tests->{IE} ) {
        $version_tests->{IE3}    = 1 if ( $major == 3 );
        $version_tests->{IE4}    = 1 if ( $major == 4 );
        $version_tests->{IE4UP}  = 1 if ( $major >= 4 );
        $version_tests->{IE5}    = 1 if ( $major == 5 );
        $version_tests->{IE5UP}  = 1 if ( $major >= 5 );
        $version_tests->{IE55}   = 1 if ( $major == 5 && $minor == 5 );
        $version_tests->{IE55UP} = 1 if ( ".$minor" >= .5 || $major >= 6 );
        $version_tests->{IE6}    = 1 if ( $major == 6 );
        $version_tests->{IE7}    = 1 if ( $major == 7 );
        $version_tests->{IE8}    = 1 if ( $major == 8 );
        $version_tests->{IE9}    = 1 if ( $major == 9 );
        $version_tests->{IE10}   = 1 if ( $major == 10 );
        $version_tests->{IE11}   = 1 if ( $major == 11 );

        $version_tests->{IE_COMPAT_MODE}
            = (    $version_tests->{IE7}
                && $tests->{TRIDENT}
                && $self->{engine_version} + 0 >= 4 );
    }

    if ( $browser_tests->{AOL} ) {
        $version_tests->{AOL3} = 1
            if ( index( $ua, "aol 3.0" ) != -1
            || $version_tests->{IE3} );
        $version_tests->{AOL4} = 1
            if ( index( $ua, "aol 4.0" ) != -1 )
            || $version_tests->{IE4};
        $version_tests->{AOL5}  = 1 if index( $ua, "aol 5.0" ) != -1;
        $version_tests->{AOL6}  = 1 if index( $ua, "aol 6.0" ) != -1;
        $version_tests->{AOLTV} = 1 if index( $ua, "navio" ) != -1;
    }

    if ( $browser_tests->{OPERA} ) {
        $version_tests->{OPERA3} = 1
            if index( $ua, "opera 3" ) != -1 || index( $ua, "opera/3" ) != -1;
        $version_tests->{OPERA4} = 1
            if ( index( $ua, "opera 4" ) != -1 )
            || ( index( $ua, "opera/4" ) != -1
            && ( index( $ua, "nintendo dsi" ) == -1 ) );
        $version_tests->{OPERA5} = 1
            if ( index( $ua, "opera 5" ) != -1 )
            || ( index( $ua, "opera/5" ) != -1 );
        $version_tests->{OPERA6} = 1
            if ( index( $ua, "opera 6" ) != -1 )
            || ( index( $ua, "opera/6" ) != -1 );
        $version_tests->{OPERA7} = 1
            if ( index( $ua, "opera 7" ) != -1 )
            || ( index( $ua, "opera/7" ) != -1 );

    }

    $minor = ".$minor";

    $self->{major} = $major;
    $self->{minor} = $minor;
    $self->{beta}  = $beta;
}

### Device tests, only run on demand

sub _init_device {
    my ($self) = @_;

    my $ua            = lc $self->{user_agent};
    my $browser_tests = $self->{browser_tests};
    my $tests         = $self->{tests};

    my ( $device, $device_name );
    my $device_tests = $self->{device_tests} = {};

    if ( index( $ua, "android" ) != -1 ) {
        $device = 'ANDROID';
        $device_tests->{$device} = 1;
    }
    elsif (index( $ua, "blackberry" ) != -1
        || index( $ua, "bb10" ) != -1
        || index( $ua, "rim tablet os" ) != -1 ) {
        $device = 'BLACKBERRY';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "ipod" ) != -1 ) {
        $device = 'IPOD';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "ipad" ) != -1 ) {
        $device = 'IPAD';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "iphone" ) != -1 ) {
        $device = 'IPHONE';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "webos" ) != -1 ) {
        $device = 'WEBOS';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "kindle" ) != -1 ) {
        $device = 'KINDLE';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "audrey" ) != -1 ) {
        $device = 'AUDREY';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "i-opener" ) != -1 ) {
        $device = 'IOPENER';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "avantgo" ) != -1 ) {
        $device                  = 'AVANTGO';
        $device_tests->{$device} = 1;
        $device_tests->{PALM}    = 1;
    }
    elsif ( index( $ua, "palmos" ) != -1 ) {
        $device = 'PALM';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "playstation 3" ) != -1 ) {
        $device = 'PS3';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "playstation portable" ) != -1 ) {
        $device = 'PSP';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "nintendo dsi" ) != -1 ) {
        $device = 'DSI';
        $device_tests->{$device} = 1;
    }
    elsif ( index( $ua, "nintendo 3ds" ) != -1 ) {
        $device = 'N3DS';
        $device_tests->{$device} = 1;
    }
    elsif (
           $browser_tests->{OBIGO}
        || index( $ua, "up.browser" ) != -1
        || (   index( $ua, "nokia" ) != -1
            && index( $ua, "windows phone" ) == -1 )
        || index( $ua, "alcatel" ) != -1
        || index( $ua, "ericsson" ) != -1
        || index( $ua, "sie-" ) == 0
        || index( $ua, "wmlib" ) != -1
        || index( $ua, " wap" ) != -1
        || index( $ua, "wap " ) != -1
        || index( $ua, "wap/" ) != -1
        || index( $ua, "-wap" ) != -1
        || index( $ua, "wap-" ) != -1
        || index( $ua, "wap" ) == 0
        || index( $ua, "wapper" ) != -1
        || index( $ua, "zetor" ) != -1
        ) {
        $device = 'WAP';
        $device_tests->{$device} = 1;
    }

    $device_tests->{MOBILE} = (
        ( $browser_tests->{FIREFOX} && index( $ua, "mobile" ) != -1 )
            || ( $browser_tests->{IE}
            && index( $ua, "windows phone" ) == -1
            && index( $ua, "arm" ) != -1 )
            || index( $ua, "up.browser" ) != -1
            || index( $ua, "nokia" ) != -1
            || index( $ua, "alcatel" ) != -1
            || index( $ua, "ericsson" ) != -1
            || index( $ua, "sie-" ) == 0
            || index( $ua, "wmlib" ) != -1
            || index( $ua, " wap" ) != -1
            || index( $ua, "wap " ) != -1
            || index( $ua, "wap/" ) != -1
            || index( $ua, "-wap" ) != -1
            || index( $ua, "wap-" ) != -1
            || index( $ua, "wap" ) == 0
            || index( $ua, "wapper" ) != -1
            || index( $ua, "blackberry" ) != -1
            || index( $ua, "iemobile" ) != -1
            || index( $ua, "palm" ) != -1
            || index( $ua, "smartphone" ) != -1
            || index( $ua, "windows ce" ) != -1
            || index( $ua, "palmsource" ) != -1
            || index( $ua, "iphone" ) != -1
            || index( $ua, "ipod" ) != -1
            || index( $ua, "ipad" ) != -1
            || ( index( $ua, "opera mini" ) != -1
            && index( $ua, "tablet" ) == -1 )
            || ( index( $ua, "android" ) != -1
            && index( $ua, "mobile" ) != -1 )
            || index( $ua, "htc_" ) != -1
            || index( $ua, "symbian" ) != -1
            || index( $ua, "webos" ) != -1
            || index( $ua, "samsung" ) != -1
            || index( $ua, "samsung" ) != -1
            || index( $ua, "zetor" ) != -1
            || index( $ua, "android" ) != -1
            || index( $ua, "symbos" ) != -1
            || index( $ua, "opera mobi" ) != -1
            || index( $ua, "fennec" ) != -1
            || index( $ua, "opera tablet" ) != -1
            || index( $ua, "rim tablet" ) != -1
            || ( index( $ua, "bb10" ) != -1
            && index( $ua, "mobile" ) != -1 )
            || $device_tests->{PSP}
            || $device_tests->{DSI}
            || $device_tests->{'N3DS'}
            || index( $ua, "googlebot-mobile" ) != -1
            || index( $ua, "msnbot-mobile" ) != -1
            || index( $ua, "bingbot-mobile" ) != -1
    );

    $device_tests->{TABLET} = (
        index( $ua, "ipad" ) != -1
            || ( $browser_tests->{IE}
            && index( $ua, "windows phone" ) == -1
            && index( $ua, "arm" ) != -1 )
            || ( index( $ua, "android" ) != -1
            && index( $ua, "mobile" ) == -1
            && index( $ua, "opera" ) == -1
            && index( $ua, "silk" ) == -1 )
            || ( $browser_tests->{FIREFOX} && index( $ua, "tablet" ) != -1 )
            || index( $ua, "kindle" ) != -1
            || index( $ua, "xoom" ) != -1
            || index( $ua, "flyer" ) != -1
            || index( $ua, "jetstream" ) != -1
            || index( $ua, "transformer" ) != -1
            || index( $ua, "novo7" ) != -1
            || index( $ua, "an10g2" ) != -1
            || index( $ua, "an7bg3" ) != -1
            || index( $ua, "an7fg3" ) != -1
            || index( $ua, "an8g3" ) != -1
            || index( $ua, "an8cg3" ) != -1
            || index( $ua, "an7g3" ) != -1
            || index( $ua, "an9g3" ) != -1
            || index( $ua, "an7dg3" ) != -1
            || index( $ua, "an7dg3st" ) != -1
            || index( $ua, "an7dg3childpad" ) != -1
            || index( $ua, "an10bg3" ) != -1
            || index( $ua, "an10bg3dt" ) != -1
            || index( $ua, "opera tablet" ) != -1
            || index( $ua, "rim tablet" ) != -1
            || index( $ua, "hp-tablet" ) != -1
    );

    if ( $browser_tests->{OBIGO} && $ua =~ /^(mot-\S+)/ ) {
        $self->{device_name} = substr $self->{user_agent}, 0, length $1;
        $self->{device_name} =~ s/^MOT-/Motorola /i;
    }
    elsif (
        $ua =~ /windows phone os [^\)]+ iemobile\/[^;]+; ([^;]+; [^;\)]+)/g )
    {
        $self->{device_name} = substr $self->{user_agent},
            pos($ua) - length $1, length $1;
        $self->{device_name} =~ s/; / /;
    }
    elsif ( $ua
        =~ /windows phone [^\)]+ iemobile\/[^;]+; arm; touch; ([^;]+; [^;\)]+)/g
        ) {
        $self->{device_name} = substr $self->{user_agent},
            pos($ua) - length $1, length $1;
        $self->{device_name} =~ s/; / /;
    }
    elsif ( $ua =~ /bb10; ([^;\)]+)/g ) {
        $self->{device_name} = 'BlackBerry ' . substr $self->{user_agent},
            pos($ua) - length $1, length $1;
        $self->{device_name} =~ s/Kbd/Q10/;
    }
    elsif ($device) {
        $self->{device_name} = $DEVICE_NAMES{ lc $device };
    }
    else {
        $self->{device_name} = undef;
    }

    if ($device) {
        $self->{device} = lc $device;
    }
    else {
        $self->{device}
            = undef;    # Means we cache the fact that we found nothing
    }
}

### Now a big block of public accessors for tests and information

# undocumented, experimental, volatile. not bothering with major/minor here as
# that's flawed for 3 point versions the plan is to move this parsing into the
# UeberAgent parser

sub os_version {
    my $self = shift;

    if (   $self->ios
        && $self->{user_agent} =~ m{OS (\d*_\d*|\d*_\d*_\d*) like Mac} ) {
        my $version = $1;
        $version =~ s{_}{.}g;
        return $version;
    }

    if ( $self->mac && $self->{user_agent} =~ m{ X \s (\d\d)_(\d)_(\d)}x ) {
        return join '.', $1, $2, $3;
    }

    # firefox in mac
    # "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:25.0) Gecko/20100101 Firefox/25.0"
    if ( $self->mac && $self->{user_agent} =~ m{ X \s (\d\d\.\d)}x ) {
        return $1;
    }

    if (   $self->winphone
        && $self->{user_agent}
        =~ m{Windows \s Phone \s \w{0,2} \s{0,1} (\d+\.\d+);}x ) {
        return $1;
    }

    if ( $self->android && $self->{user_agent} =~ m{Android ([\d\.\w-]*)} ) {
        return $1;
    }

    if ( $self->firefoxos && $self->{user_agent} =~ m{Firefox/([\d\.]*)} ) {
        return $1;
    }
}

sub browser_string {
    my ($self) = @_;
    return undef unless defined $self->{user_agent};
    return undef unless defined $self->{browser};
    return $BROWSER_NAMES{ lc $self->{browser} } || $self->{browser};
}

sub os_string {
    my ($self) = @_;

    return undef    unless defined $self->{user_agent};
    $self->_init_os unless $self->{os_tests};
    return undef    unless $self->{cached_os};
    return $OS_NAMES{ $self->{cached_os} };
}

sub _realplayer_version {
    my ( $self, $check ) = @_;

    $self->_init_version unless $self->{version_tests};
    return $self->{realplayer_version} || 0;
}

sub realplayer_browser {
    my ( $self, $check ) = @_;
    return defined( $self->{browser} ) && $self->{browser} eq 'REALPLAYER';
}

sub gecko_version {
    my ( $self, $check ) = @_;
    my $version;
    $version = $self->{gecko_version};
    if ( defined $check ) {
        return $check == $version;
    }
    else {
        return $version;
    }
}

sub version {
    my ( $self, $check ) = @_;
    $self->_init_version() unless $self->{version_tests};

    my $version = "$self->{major}$self->{minor}";
    if ( defined $check ) {
        return $check
            == $version;    # FIXME unreliable to compare floats for equality
    }
    else {
        return $version;
    }
}

sub major {
    my ( $self, $check ) = @_;
    $self->_init_version() unless $self->{version_tests};

    my ($version) = $self->{major};
    if ( defined $check ) {
        return $check == $version;
    }
    else {
        return $version;
    }
}

sub minor {
    my ( $self, $check ) = @_;
    $self->_init_version() unless $self->{version_tests};

    my ($version) = $self->{minor};
    if ( defined $check ) {
        return ( $check == $self->{minor} )
            ;    # FIXME unreliable to compare floats for equality
    }
    else {
        return $version;
    }
}

sub public_version {
    my ( $self,  $check ) = @_;
    my ( $major, $minor ) = $self->_public;

    return "$major$minor";
}

sub public_major {
    my ( $self,  $check ) = @_;
    my ( $major, $minor ) = $self->_public;

    return $major;
}

sub public_minor {
    my ( $self,  $check ) = @_;
    my ( $major, $minor ) = $self->_public;

    return $minor;
}

sub public_beta {
    my ( $self, $check ) = @_;
    my ( $major, $minor, $beta ) = $self->_public;

    return $beta;
}

sub _public {
    my ( $self, $check ) = @_;

    # Return Public version of Safari. See RT #48727.
    if ( $self->safari ) {
        my $ua = lc $self->{user_agent};

        # Safari starting with version 3.0 provides its own public version
        if (
            $ua =~ m{
                version/
                ( \d+ )       # Major version number is everything before first dot
                ( \. \d+ )?   # Minor version number is first dot and following digits
            }x
            ) {
            return ( $1, $2, undef );
        }

        # Safari before version 3.0 had only build numbers; use a lookup table
        # provided by Apple to convert to version numbers

        if ( $ua =~ m{ safari/ ( \d+ (?: \.\d+ )* ) }x ) {
            my $build   = $1;
            my $version = $safari_build_to_version{$build};
            unless ($version) {

                # if exact build -> version mapping doesn't exist, find next
                # lower build

                for my $maybe_build (
                    sort { $self->_cmp_versions( $b, $a ) }
                    keys %safari_build_to_version
                    ) {
                    $version = $safari_build_to_version{$maybe_build}, last
                        if $self->_cmp_versions( $build, $maybe_build ) >= 0;
                }

                # Special case for specific worm that uses a malformed user agent
                return ( '1', '.2', undef ) if $ua =~ m{safari/12x};
            }
            my ( $major, $minor ) = split /\./, $version;
            my $beta;
            $minor =~ s/(\D.*)// and $beta = $1;
            $minor = ( '.' . $minor );
            return ( $major, $minor, ( $beta ? 1 : undef ) );
        }
    }

    return ( $self->major, $self->minor, $self->beta($check) );
}

sub _cmp_versions {
    my ( $self, $a, $b ) = @_;

    my @a = split /\./, $a;
    my @b = split /\./, $b;

    while (@b) {
        return -1 if @a == 0 || $a[0] < $b[0];
        return 1  if @b == 0 || $b[0] < $a[0];
        shift @a;
        shift @b;
    }

    return @a <=> @b;
}

sub engine_string {
    my ( $self, $check ) = @_;

    if ( $self->gecko ) {
        return 'Gecko';
    }

    if ( $self->trident ) {
        return 'Trident';
    }

    if ( $self->ie ) {
        return 'MSIE';
    }

    if ( $self->netfront ) {
        return 'NetFront';
    }

    if ( $self->{user_agent} =~ m{\bKHTML\b} ) {
        return 'KHTML';
    }

    return undef;
}

sub _engine {
    my ($self) = @_;

    if ( defined( $self->{engine_version} ) ) {
        if ( $self->{engine_version} =~ m{(\d+)(\.\d+)?} ) {
            my $major = $1;
            my $minor = $2 || '.0';
            if (wantarray) {
                return ( $major, $minor );
            }
            else {
                return $major + $minor;
            }
        }
    }

    return undef;
}

sub engine_version {
    my ( $self, $check ) = @_;

    my $result = $self->_engine;
    return $result;
}

sub engine_major {
    my ($self) = @_;

    my @result = $self->_engine;
    return $result[0];
}

sub engine_minor {
    my ($self) = @_;

    my @result = $self->_engine;
    return $result[1];
}

sub beta {
    my ( $self, $check ) = @_;

    $self->_init_version unless $self->{version_tests};

    my ($version) = $self->{beta};
    if ($check) {
        return $check eq $version;
    }
    else {
        return $version;
    }
}

sub language {
    my ( $self, $check ) = @_;

    my $parsed = $self->_language_country();
    return $parsed->{'language'};
}

sub country {
    my ( $self, $check ) = @_;

    my $parsed = $self->_language_country();
    return $parsed->{'country'};
}

sub device {
    my ( $self, $check ) = @_;

    $self->_init_device if !exists( $self->{device} );
    return $self->{device};
}

sub device_name {
    my ( $self, $check ) = @_;

    $self->_init_device if !exists( $self->{device_name} );
    return $self->{device_name};
}

sub _language_country {
    my ( $self, $check ) = @_;

    if ( $self->safari ) {
        if (   $self->major == 1
            && $self->{user_agent} =~ m/\s ( [a-z]{2} ) \)/xms ) {
            return { language => uc $1 };
        }
        if ( $self->{user_agent} =~ m/\s ([a-z]{2})-([A-Za-z]{2})/xms ) {
            return { language => uc $1, country => uc $2 };
        }
    }

    if (   $self->aol
        && $self->{user_agent} =~ m/;([A-Z]{2})_([A-Z]{2})\)/ ) {
        return { language => $1, country => $2 };
    }

    if ( $self->{user_agent} =~ m/\b([a-z]{2})-([A-Za-z]{2})\b/xms ) {
        return { language => uc $1, country => uc $2 };
    }

    if ( $self->{user_agent} =~ m/\[([a-z]{2})\]/xms ) {
        return { language => uc $1 };
    }

    if ( $self->{user_agent} =~ m/\(([^)]+)\)/xms ) {
        my @parts = split( /;/, $1 );
        foreach my $part (@parts) {
            if ( $part =~ /^\s*([a-z]{2})\s*$/ ) {
                return { language => uc $1 };
            }
        }
    }

    return { language => undef, country => undef };
}

sub _format_minor {
    my $self = shift;
    my $minor = shift;

    return 0 + ( '.' . ( $minor || 0 ) );
}

sub browser_properties {
    my ( $self, $check ) = @_;

    my @browser_properties;

    my ( $test, $value );

    while ( ( $test, $value ) = each %{ $self->{tests} } ) {
        push @browser_properties, lc($test) if $value;
    }
    while ( ( $test, $value ) = each %{ $self->{browser_tests} } ) {
        push @browser_properties, lc($test) if $value;
    }

    $self->_init_device  unless $self->{device_tests};
    $self->_init_os      unless $self->{os_tests};
    $self->_init_robots  unless $self->{robot_tests};
    $self->_init_version unless $self->{version_tests};

    while ( ( $test, $value ) = each %{ $self->{device_tests} } ) {
        push @browser_properties, lc($test) if $value;
    }
    while ( ( $test, $value ) = each %{ $self->{os_tests} } ) {
        push @browser_properties, lc($test) if $value;
    }
    while ( ( $test, $value ) = each %{ $self->{robot_tests} } ) {
        push @browser_properties, lc($test) if $value;
    }
    while ( ( $test, $value ) = each %{ $self->{version_tests} } ) {
        push @browser_properties, lc($test) if $value;
    }

    # devices are a property too but it's not stored in %tests
    # so I explicitly test for it and add it
    push @browser_properties, 'device' if ( $self->device() );

    return sort @browser_properties;
}

sub robot_name {
    my $self = shift;

    $self->_init_robots unless exists( $self->{robot_name} );
    return $self->{robot_name};
}

1;

# ABSTRACT: Determine Web browser, version, and platform from an HTTP user agent string

__END__

=head1 SYNOPSIS

    use HTTP::BrowserDetect;

    my $browser = HTTP::BrowserDetect->new($user_agent_string);

    # Detect operating system
    if ($browser->windows) {
      if ($browser->winnt) ...
      if ($browser->win95) ...
    }
    print "Mac\n" if $browser->mac;

    # Detect browser vendor and version
    print "Netscape\n" if $browser->netscape;
    print "MSIE\n" if $browser->ie;
    if (browser->public_major(4)) {
    if ($browser->public_minor() > .5) {
        ...
    }
    }
    if ($browser->public_version() > 4) {
      ...;
    }

=head1 DESCRIPTION

The HTTP::BrowserDetect object does a number of tests on an HTTP user agent
string. The results of these tests are available via methods of the object.

This module is based upon the JavaScript browser detection code available at
L<http://www.mozilla.org/docs/web-developer/sniffer/browser_type.html>.

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

    HTTP::BrowserDetect->new( $user_agent_string )

The constructor may be called with a user agent string specified. Otherwise, it
will use the value specified by $ENV{'HTTP_USER_AGENT'}, which is set by the
web server when calling a CGI script.

=head1 SUBROUTINES/METHODS

=head2 user_agent()

Returns the value of the user agent string.

Calling this method with a parameter has now been deprecated and this feature
will be removed in an upcoming release.

=head2 country()

Returns the country string as it may be found in the user agent string. This
will be in the form of an upper case 2 character code. ie: US, DE, etc

=head2 language()

Returns the language string as it is found in the user agent string. This will
be in the form of an upper case 2 character code. ie: EN, DE, etc

=head2 device()

Returns the method name of the actual hardware, if it can be detected.
Currently returns one of: android, audrey, avantgo, blackberry, dsi, iopener, ipad,
iphone, ipod, kindle, n3ds, palm, ps3, psp, wap, webos. Returns C<undef> if no
hardware can be detected

=head2 device_name()

Returns a human formatted version of the hardware device name.  These names are
subject to change and are really meant for display purposes.  You should use
the device() method in your logic.  Returns one of: Android, Audrey,
BlackBerry, Nintendo DSi, iopener, iPad, iPhone, iPod, Amazon Kindle, Nintendo
3DS, Palm, Sony PlayStation 3, Sony Playstation Portable, WAP capable phone,
webOS. Also Windows-based smartphones will output various different names like
HTC T7575. Returns C<undef> if this is not a device or if no device name can be
detected.

=head2 browser_properties()

Returns a list of the browser properties, that is, all of the tests that passed
for the provided user_agent string. Operating systems, devices, browser names,
mobile and robots are all browser properties.

=head1 Detecting Browser Version

Please note that that the version(), major() and minor() methods have been
superceded as of release 1.07 of this module. They are not yet deprecated, but
should be replaced with public_version(), public_major() and public_minor() in
new development.

The reasoning behind this is that version() method will, in the case of Safari,
return the Safari/XXX numbers even when Version/XXX numbers are present in the
UserAgent string. Because this behaviour has been in place for so long, some
clients may have come to rely upon it. So, it has been retained in the interest
of "bugwards compatibility", but in almost all cases, the numbers returned by
public_version(), public_major() and public_minor() will be what you are
looking for.


=head2 public_version()

Returns the browser version (major and minor) as a string.

=head2 public_major()

Returns the major part of the version as a string. For example, for
Chrome 36.0.1985.67, this returns "36".

Returns undef if no version information can be detected.

=head2 public_minor()

Returns the minor part of the version as a string. This includes the
decimal point; for example, for Chrome 36.0.1985.67, this returns
".0".

Returns undef if no version information can be detected.

=head2 public_beta()

Returns any part of the version after the major and minor version, as
a string. For example, for Chrome 36.0.1985.67, this returns
".1985.67". The beta part of the string can contain any type of
alphanumeric characters.

Returns undef if no version information can be detected. Returns an
empty string if version information is detected but it contains only
a major and minor version with nothing following.

=head2 version($version)

This is probably not what you want.  Please use either public_version() or
engine_version() instead.

Returns the version as a string. If passed a parameter, returns true
if it equals the browser major version.

This function returns wrong values for some Safari versions, for
compatibility with earlier code. public_version() returns correct
version numbers for Safari.

=head2 major($major)

This is probably not what you want. Please use either public_major()
or engine_major() instead.

Returns the integer portion of the browser version as a string. If
passed a parameter, returns true if it equals the browser major
version.

This function returns wrong values for some Safari versions, for
compatibility with earlier code. public_version() returns correct
version numbers for Safari.

=head2 minor($minor)

This is probably not what you want. Please use either public_minor()
or engine_minor() instead.

Returns the decimal portion of the browser version as a string.

If passed a parameter, returns true if equals the minor version.

This function returns wrong values for some Safari versions, for
compatibility with earlier code. public_version() returns correct
version numbers for Safari.

=head2 beta($beta)

This is probably not what you want. Please use public_beta() instead.

Returns the beta version, consisting of any characters after the major
and minor version number, as a string.

This function returns wrong values for some Safari versions, for
compatibility with earlier code. public_version() returns correct
version numbers for Safari.

=head1 Detecting Rendering Engine

=head2 engine_string()

Returns one of the following:

Gecko, KHTML, Trident, MSIE, NetFront

Returns C<undef> if no string can be found.

=head2 engine_version()

Returns the version number of the rendering engine. Currently this only
returns a version number for Gecko and Trident. Returns C<undef> for all
other engines. The output is simply C<engine_major> added with C<engine_minor>.

=head2 engine_major()

Returns the major version number of the rendering engine. Currently this only
returns a version number for Gecko and Trident. Returns C<undef> for all
other engines.

=head2 engine_minor()

Returns the minor version number of the rendering engine. Currently this only
returns a version number for Gecko and Trident. Returns C<undef> for all
other engines.

=head1 Detecting OS Platform and Version

The following methods are available, each returning a true or false value.
Some methods also test for the operating system version. The indentations
below show the hierarchy of tests (for example, win2k is considered a type of
winnt, which is a type of win32)

=head2 windows()

    win16 win3x win31
    win32
        winme win95 win98
        winnt
            win2k winxp win2k3 winvista win7
            win8
                win8_0 win8_1
    wince
    winphone
        winphone7 winphone7_5 winphone8

=head2 dotnet()

=head2 chromeos()

=head2 firefoxos()

=head2 mac()

mac68k macppc macosx ios

=head2 os2()

=head2 bb10()

=head2 rimtabletos()

=head2 unix()

  sun sun4 sun5 suni86 irix irix5 irix6 hpux hpux9 hpux10
  aix aix1 aix2 aix3 aix4 linux sco unixware mpras reliant
  dec sinix freebsd bsd

=head2 vms()

=head2 amiga()

=head2 ps3gameos()

=head2 pspgameos()

It may not be possibile to detect Win98 in Netscape 4.x and earlier. On Opera
3.0, the userAgent string includes "Windows 95/NT4" on all Win32, so you can't
distinguish between Win95 and WinNT.

=head2 os_string()

Returns one of the following strings, or undef. This method exists solely for
compatibility with the L<HTTP::Headers::UserAgent> module.

  Win95, Win98, WinME, WinNT, Win2K, WinXP, Win2k3, WinVista, Win7, Win8,
  Win8.1, Windows Phone, Mac, Mac OS X, iOS, Win3x, OS2, Unix, Linux,
  Chrome OS, Firefox OS, Playstation 3 GameOS, Playstation Portable GameOS,
  RIM Tablet OS, BlackBerry 10

=head1 Detecting Browser Vendor

The following methods are available, each returning a true or false value.
Some methods also test for the browser version, saving you from checking the
version separately.

=head3 aol aol3 aol4 aol5 aol6

=head3 chrome

=head3 curl

=head3 emacs

=head3 firefox

=head3 gecko

=head3 icab

=head3 ie ie3 ie4 ie4up ie5 ie5up ie55 ie55up ie6 ie7 ie8 ie9 ie10 ie11

=head3 ie_compat_mode

The ie_compat_mode is used to determine if the IE user agent is for
the compatibility mode view, in which case the real version of IE is
higher than that detected. The true version of IE can be inferred from
the version of Trident in the engine_version method.

=head3 java

=head3 konqueror

=head3 lotusnotes

=head3 lynx links elinks

=head3 mobile_safari

=head3 mosaic

=head3 mozilla

=head3 neoplanet neoplanet2

=head3 netfront

=head3 netscape nav2 nav3 nav4 nav4up nav45 nav45up navgold nav6 nav6up

=head3 opera opera3 opera4 opera5 opera6 opera7

=head3 realplayer

The realplayer method above tests for the presence of either the RealPlayer
plug-in "(r1 " or the browser "RealPlayer".

=head3 realplayer_browser

The realplayer_browser method tests for the presence of the RealPlayer
browser (but returns 0 for the plugin).

=head3 safari

=head3 staroffice

=head3 webtv

Netscape 6, even though its called six, in the User-Agent string has version
number 5. The nav6 and nav6up methods correctly handle this quirk. The Firefox
test correctly detects the older-named versions of the browser (Phoenix,
Firebird).

=head2 browser_string()

Returns undef on failure.  Otherwise returns one of the following:

Netscape, Firefox, Safari, Chrome, MSIE, WebTV, AOL Browser, Opera, Mosaic,
Lynx, Links, ELinks, RealPlayer, IceWeasel, curl, puf, NetFront, Mobile Safari,
BlackBerry, Obigo, Nintendo DSi, Nintendo 3DS, StarOffice, Lotus Notes, iCab.

=head2 gecko_version()

If a Gecko rendering engine is used (as in Mozilla or Firefox), returns the
version of the renderer (e.g. 1.3a, 1.7, 1.8) This might be more useful than
the particular browser name or version when correcting for quirks in different
versions of this rendering engine. If no Gecko browser is being used, or the
version number can't be detected, returns undef.

=head1 Detecting Other Devices

The following methods are available, each returning a true or false value.

=head3 android

=head3 audrey

=head3 avantgo

=head3 blackberry

=head3 dsi

=head3 iopener

=head3 iphone

=head3 ipod

=head3 ipad

=head3 kindle

=head3 n3ds

=head3 obigo

=head3 palm

=head3 webos

=head3 wap

=head3 psp

=head3 ps3

=head2 mobile()

Returns true if the browser appears to belong to a handheld device.

=head2 tablet()

Returns true if the browser appears to belong to a tablet device.

=head2 robot()

Returns true if the user agent appears to be a robot, spider, crawler, or other
automated Web client.

The following additional methods are available, each returning a true or false
value. This is by no means a complete list of robots that exist on the Web.

=head3 ahrefs

=head3 altavista

=head3 askjeeves

=head3 baidu

=head3 facebook

=head3 getright

=head3 google

=head3 googleadsbot

=head3 googleadsense

=head3 googlemobile

=head3 infoseek

=head3 linkexchange

=head3 lwp

=head3 lycos

=head3 mj12bot

=head3 msn (same as bing)

=head3 puf

=head3 slurp

=head3 webcrawler

=head3 wget

=head3 yahoo

=head3 yandex

=head3 yandeximages

=head1 CREDITS

Lee Semel, lee@semel.net (Original Author)

Peter Walsham (co-maintainer)

Olaf Alders, C<olaf at wundercounter.com> (co-maintainer)

=head1 ACKNOWLEDGEMENTS

Thanks to the following for their contributions:

cho45

Leonardo Herrera

Denis F. Latypoff

merlynkline

Simon Waters

Toni Cebrin

Florian Merges

david.hilton.p

Steve Purkis

Andrew McGregor

Robin Smidsrod

Richard Noble

Josh Ritter

Mike Clarke

Marc Sebastian Pelzer

Alexey Surikov

Maros Kollar

Jay Rifkin

Luke Saunders

Jacob Rask

Heiko Weber

Jon Jensen

Jesse Thompson

Graham Barr

Enrico Sorcinelli

Olivier Bilodeau

Yoshiki Kurihara

Paul Findlay

Uwe Voelker

Douglas Christopher Wilson

John Oatis

Atsushi Kato

Ronald J. Kimball

Bill Rhodes

Thom Blake

Aran Deltac

yeahoffline

David Ihnen

Hao Wu

Perlover

=head1 TO DO

The C<_engine()> method currently only handles Gecko and Trident.  It needs to
be expanded to handle other rendering engines.

POD coverage is also not 100%.

=head1 SEE ALSO

"Browser ID (User-Agent) Strings", L<http://www.zytrax.com/tech/web/browser_ids.htm>

L<HTML::ParseBrowser>.

=head1

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTTP::BrowserDetect

You can also look for information at:

=over 4

=item * GitHub Source Repository

L<http://github.com/oalders/http-browserdetect>

=item * Reporting Issues

L<https://github.com/oalders/http-browserdetect/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTTP-BrowserDetect>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTTP-BrowserDetect>

=item * Search CPAN

L<https://metacpan.org/module/HTTP::BrowserDetect>

=back

=head1 BUGS AND LIMITATIONS

The biggest limitation at this point is the test suite, which really needs to
have many more UserAgent strings to test against.

=head1 CONTRIBUTING

Patches are certainly welcome, with many thanks for the excellent contributions
which have already been received. The preferred method of patching would be to
fork the GitHub repo and then send me a pull request, but plain old patch files
are also welcome.

If you're able to add test cases, this will speed up the time to release your
changes. Just edit t/useragents.json so that the test coverage includes any
changes you have made. Please contact me if you have any questions.

This distribution uses L<Dist::Zilla>. If you're not familiar with this module,
please see L<https://github.com/oalders/http-browserdetect/issues/5> for some
helpful tips to get you started.

=cut
