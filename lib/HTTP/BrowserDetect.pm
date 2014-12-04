use strict;
use warnings;

use 5.006;

package HTTP::BrowserDetect;

use vars qw(@ALL_TESTS);

# Operating Systems
our @OS_TESTS = qw(
    windows mac   os2
    unix    linux vms
    bsd     amiga firefoxos
    bb10    rimtabletos
    chromeos
);

# More precise Windows
our @WINDOWS_TESTS = qw(
    win16    win3x     win31
    win95    win98     winnt
    winme    win32     win2k
    winxp    win2k3    winvista
    win7     win8      win8_0
    win8_1   wince     winphone
    winphone7  winphone7_5  winphone8
);

# More precise Mac
our @MAC_TESTS = qw(
    macosx mac68k macppc
    ios
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

# Devices
our %DEVICE_TESTS = (
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

# Browsers
our @BROWSER_TESTS = qw(
    mosaic        netscape    firefox
    chrome        safari      ie
    opera         lynx        links
    elinks        neoplanet   neoplanet2
    avantgo       emacs       mozilla
    konqueror     r1          netfront
    mobile_safari obigo
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
    aol         aol3        aol4
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

our @ENGINE_TESTS = qw(
    gecko    trident
);

# https://support.google.com/webmasters/answer/1061943?hl=en

my %ROBOTS = (
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
    icab            => 'iCab',
    infoseek        => 'InfoSeek',
    linkchecker     => 'LinkChecker',
    linkexchange    => 'LinkExchange',
    lotusnotes      => 'Lotus Notes',
    lwp             => 'LWP::UserAgent',
    lycos           => 'Lycos',
    mj12bot         => 'Majestic-12 DSearch',
    msn             => 'MSN',
    msnmobile       => 'MSN Mobile',
    puf             => 'puf',
    robot           => 'robot',
    slurp           => 'Yahoo! Slurp',
    specialarchiver => 'archive.org_bot',
    staroffice      => 'StarOffice',
    webcrawler      => 'WebCrawler',
    webtv           => 'WebTV',
    wget            => 'wget',
    yahoo           => 'Yahoo',
    yandex          => 'Yandex',
    yandeximages    => 'YandexImages',
);

our @ROBOT_TESTS = qw(
    puf          curl        wget
    getright     robot       slurp
    yahoo        mj12bot
    altavista    lycos       infoseek
    lwp          webcrawler  linkexchange
    webtv        staroffice
    lotusnotes   icab        googlemobile
    msn          msnmobile
    facebook     baidu       googleadsbot
    askjeeves    googleadsense googlebotvideo
    googlebotnews googlebotimage google
    linkchecker  yandeximages specialarchiver
    yandex       ahrefs
);

our @MISC_TESTS = qw(
    mobile      dotnet      x11
    java        tablet
);

push @ALL_TESTS,
    (
    @OS_TESTS,                       @WINDOWS_TESTS,
    @MAC_TESTS,                      @UNIX_TESTS,
    @BSD_TESTS,                      @GAMING_TESTS,
    ( sort ( keys %DEVICE_TESTS ) ), @BROWSER_TESTS,
    @IE_TESTS,                       @OPERA_TESTS,
    @AOL_TESTS,                      @NETSCAPE_TESTS,
    @FIREFOX_TESTS,                  @ENGINE_TESTS,
    @ROBOT_TESTS,                    @MISC_TESTS,
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

    $self->user_agent( $user_agent );
    return $self;
}

foreach my $test ( @ALL_TESTS ) {
    no strict 'refs';
    my $key = uc $test;
    *{$test} = sub {
        my ( $self ) = _self_or_default( @_ );
        return $self->{tests}->{$key};
    };
}

sub _self_or_default {
    my ( $self ) = $_[0];
    return @_
        if ( defined $self
        && ref $self
        && ( ref $self eq 'HTTP::BrowserDetect' )
        || UNIVERSAL::isa( $self, 'HTTP::BrowserDetect' ) );
    $default ||= HTTP::BrowserDetect->new();
    unshift( @_, $default );
    return @_;
}

sub user_agent {
    my ( $self, $user_agent ) = _self_or_default( @_ );
    if ( defined $user_agent ) {
        $self->{user_agent} = $user_agent;
        $self->_test();
    }
    return $self->{user_agent};
}

# Private method -- test the UA string
sub _test {
    my ( $self ) = @_;

    $self->{tests} = {};
    my $tests = $self->{tests};
    $self->_os_tests;
    $self->_robot_tests;

    my @ff = ( 'firefox', @FIREFOX_TESTS );
    my $ff = join "|", @ff;

    my $ua = lc $self->{user_agent};

    # Trident Engine (detect early for sniffing out IE)
    $tests->{TRIDENT} = ( index( $ua, "trident/" ) != -1 );

    if ( $tests->{TRIDENT} && $ua =~ /trident\/([\w\.\d]*)/ ) {
        $self->{engine_version} = $1;
    }

    # Browser version
    my ( $major, $minor, $beta ) = (
        $ua =~ m{
            \S+                     # Greedly catch anything leading up to forward slash.
            \/                      # Version starts with a slash
            [A-Za-z]*               # Eat any letters before the major version
            ( [0-9A-Za-z]* )        # Major version number is everything before the first dot
            \.                      # The first dot
            ( [\d]* )               # Minor version number is every digit after the first dot
            [\d.]*                  # Throw away remaining numbers and dots
            ( [^\s]* )              # Beta version string is up to next space
        }x
    );

    # Firefox version
    if ($ua =~ m{
                ($ff)
                \/
                ( [^.]* )           # Major version number is everything before first dot
                \.                  # The first dot
                ( [\d]* )           # Minor version nnumber is digits after first dot
            }xo
        )
    {
        $major               = $2;
        $minor               = $3;
        $tests->{ uc( $1 ) } = 1;
        $tests->{'FIREFOX'}  = 1;

    }

    # IE (and others) version
    if ( $ua =~ m{\b msie \s ( [0-9\.]+ ) (?: [a-z]+ [a-z0-9]* )? ;}x ) {

        # Internet Explorer
        ( $major, $minor, $beta ) = split /\./, $1;
    }
    elsif ( $ua
        =~ m{\b compatible; \s* [\w\-]* / ( [0-9\.]* ) (?: [a-z]+ [a-z0-9\.]* )? ;}x
        )
    {
        # Generic "compatible" formats
        ( $major, $minor, $beta ) = split /\./, $1;

    }
    elsif ( $tests->{TRIDENT} && $ua =~ m{\b rv: ( [0-9\.]+ ) \b}x ) {

        # MSIE masking as Gecko really well ;)
        ( $major, $minor, $beta ) = split /\./, $1;
    }

    # Opera browsers

    $tests->{OPERA}
        = ( index( $ua, "opera" ) != -1 || index( $ua, "opr/" ) != -1 );
    $tests->{OPERA3}
        = ( index( $ua, "opera 3" ) != -1 || index( $ua, "opera/3" ) != -1 );
    $tests->{OPERA4} = ( index( $ua, "opera 4" ) != -1 )
        || ( index( $ua, "opera/4" ) != -1
        && ( index( $ua, "nintendo dsi" ) == -1 ) );
    $tests->{OPERA5} = ( index( $ua, "opera 5" ) != -1 )
        || ( index( $ua, "opera/5" ) != -1 );
    $tests->{OPERA6} = ( index( $ua, "opera 6" ) != -1 )
        || ( index( $ua, "opera/6" ) != -1 );
    $tests->{OPERA7} = ( index( $ua, "opera 7" ) != -1 )
        || ( index( $ua, "opera/7" ) != -1 );

# Opera needs to be dealt with specifically
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
    elsif ( $ua =~ m{NetFront/(\d*)\.(\d*) Kindle}i ) {
        $major = $1;
        $minor = $2;
    }
    elsif ( $ua =~ m{Nintendo 3DS;.*\sVersion/(\d*)\.(\d*)}i ) {
        $major = $1;
        $minor = $2;
    }

    $major = 0 if !$major;
    $minor = $self->_format_minor( $minor );

    # Mozilla browsers

    $tests->{GECKO} = ( index( $ua, "gecko" ) != -1 )
        && ( index( $ua, "like gecko" ) == -1 );

    $tests->{CHROME}
        = ( !$tests->{OPERA} && index( $ua, "chrome/" ) != -1 )
        ;    #&& $ua =~ m{chrome/ ( [^.]* ) \. ( [^.]* )}x );
    $tests->{SAFARI}
        = (    ( index( $ua, "safari" ) != -1 )
            || ( index( $ua, "applewebkit" ) != -1 ) )
        && ( index( $ua, "chrome" ) == -1 );
    $tests->{MOBILE_SAFARI}
        = ( $tests->{SAFARI} && index( $ua, " mobile safari/" ) >= 0 );

    # Chrome Version
    if ( $tests->{CHROME} ) {
        ( $major, $minor ) = (
            $ua =~ m{
                chrome
                \/
                ( \d+ )       # Major version number
                ( \. \d+ )?   # Minor version number is dot and following digits
            }x
        );
    }

    # Safari Version
    elsif ( $tests->{SAFARI} ) {
        my ( $safari_build, $safari_minor ) = (
            $ua =~ m{
                safari/
                ( \d+ )       # Major version number
                ( \. \d+ )?   # Minor version number is dot and following digits
            }x
        );

        if ( !$safari_build && $ua =~ m{applewebkit\/([\d\.]{1,})}xi ) {

            # ignore digits after 2nd dot
            ( $safari_build, $safari_minor ) = split /\./, $1;
        }

        if ( $safari_build ) {
            $major = int( $safari_build / 100 );
            $minor = int( $safari_build % 100 ) / 100;
            $beta  = $safari_minor;
        }
    }

    # Gecko-powered Netscape (i.e. Mozilla) versions
    $tests->{NETSCAPE}
        = (    !$tests->{FIREFOX}
            && !$tests->{SAFARI}
            && !$tests->{CHROME}
            && !$tests->{OPERA}
            && !$tests->{TRIDENT}
            && index( $ua, "mozilla" ) != -1
            && index( $ua, "msie" ) == -1
            && index( $ua, "spoofer" ) == -1
            && index( $ua, "compatible" ) == -1
            && index( $ua, "webtv" ) == -1
            && index( $ua, "hotjava" ) == -1
            && index( $ua, "nintendo" ) == -1
            && index( $ua, "playstation 3" ) == -1
            && index( $ua, "playstation portable" ) == -1 );

    if (   $tests->{GECKO}
        && $tests->{NETSCAPE}
        && index( $ua, "netscape" ) != -1 )
    {
        ( $major, $minor, $beta ) = (
            $ua =~ m{
                netscape6?\/
                ( [^.]* )      # Major version number is everything before first dot
                \.             # The first dot
                ( [\d]* )      # Minor version nnumber is digits after first dot
                ( [^\s]* )
            }x
        );
        $minor = 0 + ".$minor";
    }

    # Netscape browsers
    $tests->{NAV2}    = ( $tests->{NETSCAPE} && $major == 2 );
    $tests->{NAV3}    = ( $tests->{NETSCAPE} && $major == 3 );
    $tests->{NAV4}    = ( $tests->{NETSCAPE} && $major == 4 );
    $tests->{NAV4UP}  = ( $tests->{NETSCAPE} && $major >= 4 );
    $tests->{NAV45}   = ( $tests->{NETSCAPE} && $major == 4 && $minor == .5 );
    $tests->{NAV45UP} = ( $tests->{NAV4}     && $minor >= .5 )
        || ( $tests->{NETSCAPE} && $major >= 5 );
    $tests->{NAVGOLD} = ( defined( $beta ) && index( $beta, "gold" ) != -1 );
    $tests->{NAV6} = ( $tests->{NETSCAPE} && ( $major == 5 || $major == 6 ) )
        ;    # go figure
    $tests->{NAV6UP} = ( $tests->{NETSCAPE} && $major >= 5 );

    $tests->{MOZILLA} = ( $tests->{NETSCAPE} && $tests->{GECKO} );

    # Internet Explorer browsers

    $tests->{IE}
        = (    $tests->{TRIDENT}
            || index( $ua, "msie" ) != -1
            || index( $ua, 'microsoft internet explorer' ) != -1 );
    $tests->{IE3}    = ( $tests->{IE}  && $major == 3 );
    $tests->{IE4}    = ( $tests->{IE}  && $major == 4 );
    $tests->{IE4UP}  = ( $tests->{IE}  && $major >= 4 );
    $tests->{IE5}    = ( $tests->{IE}  && $major == 5 );
    $tests->{IE5UP}  = ( $tests->{IE}  && $major >= 5 );
    $tests->{IE55}   = ( $tests->{IE}  && $major == 5 && $minor >= .5 );
    $tests->{IE55UP} = ( $tests->{IE5} && $minor >= .5 )
        || ( $tests->{IE} && $major >= 6 );
    $tests->{IE6}  = ( $tests->{IE} && $major == 6 );
    $tests->{IE7}  = ( $tests->{IE} && $major == 7 );
    $tests->{IE8}  = ( $tests->{IE} && $major == 8 );
    $tests->{IE9}  = ( $tests->{IE} && $major == 9 );
    $tests->{IE10} = ( $tests->{IE} && $major == 10 );
    $tests->{IE11} = ( $tests->{IE} && $major == 11 );

    $tests->{IE_COMPAT_MODE}
        = (    $tests->{IE7}
            && $tests->{TRIDENT}
            && $self->{engine_version} + 0 >= 4 );

    # Neoplanet browsers

    $tests->{NEOPLANET} = ( index( $ua, "neoplanet" ) != -1 );
    $tests->{NEOPLANET2}
        = ( $tests->{NEOPLANET} && index( $ua, "2." ) != -1 );

    # AOL Browsers

    $tests->{AOL}  = ( index( $ua, "aol" ) != -1 );
    $tests->{AOL3} = ( index( $ua, "aol 3.0" ) != -1 )
        || ( $tests->{AOL} && $tests->{IE3} );
    $tests->{AOL4} = ( index( $ua, "aol 4.0" ) != -1 )
        || ( $tests->{AOL} && $tests->{IE4} );
    $tests->{AOL5}  = ( index( $ua, "aol 5.0" ) != -1 );
    $tests->{AOL6}  = ( index( $ua, "aol 6.0" ) != -1 );
    $tests->{AOLTV} = ( index( $ua, "navio" ) != -1 )
        || ( index( $ua, "navio_aoltv" ) != -1 );

    # Other browsers

    $tests->{STAROFFICE} = ( index( $ua, "staroffice" ) != -1 );
    $tests->{ICAB}       = ( index( $ua, "icab" ) != -1 );
    $tests->{LOTUSNOTES} = ( index( $ua, "lotus-notes" ) != -1 );
    $tests->{KONQUEROR}  = ( index( $ua, "konqueror" ) != -1 );
    $tests->{LYNX}       = ( index( $ua, "lynx" ) != -1 );
    $tests->{LINKS}      = ( index( $ua, "links" ) != -1 );
    $tests->{ELINKS}     = ( index( $ua, "elinks" ) != -1 );
    $tests->{WEBTV}      = ( index( $ua, "webtv" ) != -1 );
    $tests->{MOSAIC}     = ( index( $ua, "mosaic" ) != -1 );
    $tests->{JAVA}
        = (    index( $ua, "java" ) != -1
            || index( $ua, "jdk" ) != -1
            || index( $ua, "jakarta commons-httpclient" ) != -1 );

    $tests->{NETFRONT}
        = (    index( $ua, "playstation 3" ) != -1
            || index( $ua, "playstation portable" ) != -1
            || index( $ua, "netfront" ) != -1 );

    # Devices

    $tests->{BLACKBERRY}
        = (    index( $ua, "blackberry" ) != -1
            || index( $ua, "bb10" ) != -1
            || index( $ua, "rim tablet os" ) != -1 );
    $tests->{IPHONE}   = ( index( $ua, "iphone" ) != -1 );
    $tests->{WINCE}    = ( index( $ua, "windows ce" ) != -1 );
    $tests->{WINPHONE} = ( index( $ua, "windows phone" ) != -1 );
    $tests->{WEBOS}    = ( index( $ua, "webos" ) != -1 );
    $tests->{IPOD}     = ( index( $ua, "ipod" ) != -1 );
    $tests->{IPAD}     = ( index( $ua, "ipad" ) != -1 );
    $tests->{KINDLE}   = ( index( $ua, "kindle" ) != -1 );
    $tests->{AUDREY}   = ( index( $ua, "audrey" ) != -1 );
    $tests->{IOPENER}  = ( index( $ua, "i-opener" ) != -1 );
    $tests->{AVANTGO}  = ( index( $ua, "avantgo" ) != -1 );
    $tests->{PALM} = ( $tests->{AVANTGO} || index( $ua, "palmos" ) != -1 );
    $tests->{OBIGO} = ( index( $ua, "obigo/" ) != -1 );
    $tests->{WAP}
        = (    $tests->{OBIGO}
            || index( $ua, "up.browser" ) != -1
            || ( index( $ua, "nokia" ) != -1 && !$tests->{WINPHONE} )
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
            || index( $ua, "zetor" ) != -1 );
    $tests->{PS3}    = ( index( $ua, "playstation 3" ) != -1 );
    $tests->{PSP}    = ( index( $ua, "playstation portable" ) != -1 );
    $tests->{DSI}    = ( index( $ua, "nintendo dsi" ) != -1 );
    $tests->{'N3DS'} = ( index( $ua, "nintendo 3ds" ) != -1 );

    $tests->{MOBILE} = (
        ( $tests->{FIREFOX} && index( $ua, "mobile" ) != -1 )
            || ( $tests->{IE}
            && !$tests->{WINPHONE}
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
            || $tests->{PSP}
            || $tests->{DSI}
            || $tests->{'N3DS'}
            || $tests->{GOOGLEMOBILE}
            || $tests->{MSNMOBILE}
    );

    $tests->{TABLET} = (
        index( $ua, "ipad" ) != -1
            || ( $tests->{IE}
            && !$tests->{WINPHONE}
            && index( $ua, "arm" ) != -1 )
            || ( index( $ua, "android" ) != -1
            && index( $ua, "mobile" ) == -1
            && index( $ua, "opera" ) == -1 )
            || ( $tests->{FIREFOX} && index( $ua, "tablet" ) != -1 )
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
            || index( $ua, "hp-tablet" )
            != -1

    );

    # Operating System

    # A final try at browser version, if we haven't gotten it so far
    if ( !defined( $major ) || $major eq '' ) {
        if ( $ua =~ /[A-Za-z]+\/(\d+)\;/ ) {
            $major = $1;
            $minor = 0;
        }

    }

    # Gecko version
    $self->{gecko_version} = undef;
    if ( $tests->{GECKO} ) {
        if ( $ua =~ /\([^)]*rv:([\w.\d]*)/ ) {
            $self->{gecko_version}  = $1;
            $self->{engine_version} = $1;
        }
    }

    # RealPlayer
    $tests->{REALPLAYER}
        = ( index( $ua, "(r1 " ) != -1 || index( $ua, "realplayer" ) != -1 );

    $self->{realplayer_version} = undef;
    if ( $tests->{REALPLAYER} ) {
        if ( $ua =~ /realplayer\/([\d+\.]+)/ ) {
            $self->{realplayer_version} = $1;
            my @version = split( /\./, $self->{realplayer_version} );
            $major = shift @version;
            $minor = shift @version;
        }
        elsif ( $ua =~ /realplayer\s(\w+)/ ) {
            $self->{realplayer_version} = $1;
        }
    }

    # Device from UA

    $self->{device_name} = undef;

    if ( $tests->{OBIGO} && $ua =~ /^(mot-\S+)/ ) {
        $self->{device_name} = substr $self->{user_agent}, 0, length $1;
        $self->{device_name} =~ s/^MOT-/Motorola /i;
    }
    elsif (
        $ua =~ /windows phone os [^\)]+ iemobile\/[^;]+; ([^;]+; [^;\)]+)/g )
    {
        $self->{device_name} = substr $self->{user_agent},
            pos( $ua ) - length $1, length $1;
        $self->{device_name} =~ s/; / /;
    }
    elsif ( $ua
        =~ /windows phone [^\)]+ iemobile\/[^;]+; arm; touch; ([^;]+; [^;\)]+)/g
        )
    {
        $self->{device_name} = substr $self->{user_agent},
            pos( $ua ) - length $1, length $1;
        $self->{device_name} =~ s/; / /;
    }
    elsif ( $ua =~ /bb10; ([^;\)]+)/g ) {
        $self->{device_name} = 'BlackBerry ' . substr $self->{user_agent},
            pos( $ua ) - length $1, length $1;
        $self->{device_name} =~ s/Kbd/Q10/;
    }

    $self->{major} = $major;
    $self->{minor} = $minor;
    $self->{beta}  = $beta;

    $self->_os_tests;
    $self->_robot_tests;

    return undef unless $self->robot;

}

sub _robot_tests {
    my $self  = shift;
    my $ua    = lc $self->{user_agent};
    my $tests = $self->{tests};

    $tests->{LWP}
        = ( index( $ua, "libwww-perl" ) != -1 || index( $ua, "lwp-" ) != -1 );
    $tests->{YAHOO} = ( index( $ua, "yahoo" ) != -1 )
        && ( index( $ua, 'jp.co.yahoo.android' ) == -1 );
    $tests->{MSN} = (
        ( index( $ua, "msnbot" ) != -1 || index( $ua, "bingbot" ) ) != -1 );
    $tests->{MSNMOBILE} = (
        (          index( $ua, "msnbot-mobile" ) != -1
                || index( $ua, "bingbot-mobile" )
        ) != -1
    );

    $tests->{AHREFS}         = ( index( $ua, "ahrefsbot" ) != -1 );
    $tests->{ALTAVISTA}      = ( index( $ua, "altavista" ) != -1 );
    $tests->{ASKJEEVES}      = ( index( $ua, "ask jeeves/teoma" ) != -1 );
    $tests->{BAIDU}          = ( index( $ua, "baiduspider" ) != -1 );
    $tests->{CURL}           = ( index( $ua, "libcurl" ) != -1 );
    $tests->{FACEBOOK}       = ( index( $ua, "facebookexternalhit" ) != -1 );
    $tests->{GETRIGHT}       = ( index( $ua, "getright" ) != -1 );
    $tests->{GOOGLEADSBOT}   = ( index( $ua, "adsbot-google" ) != -1 );
    $tests->{GOOGLEADSENSE}  = ( index( $ua, "mediapartners-google" ) != -1 );
    $tests->{GOOGLEBOTIMAGE} = ( index( $ua, "googlebot-image" ) != -1 );
    $tests->{GOOGLEBOTNEWS}  = ( index( $ua, "googlebot-news" ) != -1 );
    $tests->{GOOGLEBOTVIDEO} = ( index( $ua, "googlebot-video" ) != -1 );
    $tests->{GOOGLEMOBILE}   = ( index( $ua, "googlebot-mobile" ) != -1 );
    $tests->{GOOGLE}         = ( index( $ua, "googlebot" ) != -1 );
    $tests->{INFOSEEK}       = ( index( $ua, "infoseek" ) != -1 );
    $tests->{LINKEXCHANGE}   = ( index( $ua, "lecodechecker" ) != -1 );
    $tests->{LINKCHECKER}    = ( index( $ua, "linkchecker" ) != -1 );
    $tests->{LYCOS}          = ( index( $ua, "lycos" ) != -1 );
    $tests->{MJ12BOT}        = ( index( $ua, "mj12bot/" ) != -1 );
    $tests->{PUF}            = ( index( $ua, "puf/" ) != -1 );
    $tests->{SCOOTER}        = ( index( $ua, "scooter" ) != -1 );
    $tests->{SLURP}          = ( index( $ua, "slurp" ) != -1 );
    $tests->{SPECIALARCHIVER} = ( index( $ua, "special_archiver" ) != -1 );
    $tests->{WEBCRAWLER}      = ( index( $ua, "webcrawler" ) != -1 );
    $tests->{WGET}            = ( index( $ua, "wget" ) != -1 );
    $tests->{YANDEX}          = ( index( $ua, "yandexbot" ) != -1 );
    $tests->{YANDEXIMAGES}    = ( index( $ua, "yandeximages" ) != -1 );

    $tests->{ROBOT}
        = (    $tests->{AHREFS}
            || $tests->{ALTAVISTA}
            || $tests->{ASKJEEVES}
            || $tests->{BAIDU}
            || $tests->{FACEBOOK}
            || $tests->{GETRIGHT}
            || $tests->{GOOGLEADSBOT}
            || $tests->{GOOGLEADSENSE}
            || $tests->{GOOGLEMOBILE}
            || $tests->{GOOGLEBOTNEWS}
            || $tests->{GOOGLEBOTIMAGE}
            || $tests->{GOOGLEBOTVIDEO}
            || $tests->{GOOGLE}
            || $tests->{INFOSEEK}
            || $tests->{JAVA}
            || $tests->{LINKEXCHANGE}
            || $tests->{LINKCHECKER}
            || $tests->{LWP}
            || $tests->{LYCOS}
            || $tests->{MSNMOBILE}
            || $tests->{MSN}
            || $tests->{PUF}
            || $tests->{SLURP}
            || $tests->{SPECIALARCHIVER}
            || $tests->{WEBCRAWLER}
            || $tests->{WGET}
            || $tests->{YAHOO}
            || $tests->{YANDEX}
            || $tests->{YANDEXIMAGES} )
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

    # Yahoo Slurp! hack this should apply to most browsers, but there's a case
    # where GoogleBot masquerades as Safari on iOS.  not sure how to handle
    # that.

    delete $tests->{FIREFOX} if $self->robot;
}

sub _os_tests {
    my $self  = shift;
    my $tests = $self->{tests};
    my $ua    = lc $self->{user_agent};

    $tests->{WIN16}
        = (    index( $ua, "win16" ) != -1
            || index( $ua, "16bit" ) != -1
            || index( $ua, "windows 3" ) != -1
            || index( $ua, "windows 16-bit" ) != -1 );
    $tests->{WIN3X}
        = (    index( $ua, "win16" ) != -1
            || index( $ua, "windows 3" ) != -1
            || index( $ua, "windows 16-bit" ) != -1 );
    $tests->{WIN31}
        = (    index( $ua, "win16" ) != -1
            || index( $ua, "windows 3.1" ) != -1
            || index( $ua, "windows 16-bit" ) != -1 );
    $tests->{WIN95}
        = ( index( $ua, "win95" ) != -1 || index( $ua, "windows 95" ) != -1 );
    $tests->{WIN98}
        = ( index( $ua, "win98" ) != -1 || index( $ua, "windows 98" ) != -1 );
    $tests->{WINNT}
        = (    index( $ua, "winnt" ) != -1
            || index( $ua, "windows nt" ) != -1
            || index( $ua, "nt4" ) != -1
            || index( $ua, "nt3" ) != -1 );
    $tests->{WIN2K}
        = ( index( $ua, "nt 5.0" ) != -1 || index( $ua, "nt5" ) != -1 );
    $tests->{WINXP}    = ( index( $ua, "nt 5.1" ) != -1 );
    $tests->{WIN2K3}   = ( index( $ua, "nt 5.2" ) != -1 );
    $tests->{WINVISTA} = ( index( $ua, "nt 6.0" ) != -1 );
    $tests->{WIN7}     = ( index( $ua, "nt 6.1" ) != -1 );
    $tests->{WIN8_0}   = ( index( $ua, "nt 6.2" ) != -1 );
    $tests->{WIN8_1}   = ( index( $ua, "nt 6.3" ) != -1 );
    $tests->{WIN8} = ( $tests->{WIN8_0} || $tests->{WIN8_1} );
    $tests->{DOTNET} = ( index( $ua, ".net clr" ) != -1 );

    $tests->{WINME} = ( index( $ua, "win 9x 4.90" ) != -1 );    # whatever
    $tests->{WIN32} = (
        (          $tests->{WIN95}
                || $tests->{WIN98}
                || $tests->{WINME}
                || $tests->{WINNT}
                || $tests->{WIN2K}
        )
            || $tests->{WINXP}
            || $tests->{WIN2K3}
            || $tests->{WINVISTA}
            || $tests->{WIN7}
            || $tests->{WIN8}
            || index( $ua, "win32" ) != -1
    );
    $tests->{WINDOWS} = (
        (          $tests->{WIN16}
                || $tests->{WIN31}
                || $tests->{WIN95}
                || $tests->{WIN98}
                || $tests->{WINNT}
                || $tests->{WIN32}
                || $tests->{WIN2K}
                || $tests->{WINXP}
                || $tests->{WIN2K3}
                || $tests->{WINVISTA}
                || $tests->{WIN7}
                || $tests->{WIN8}
                || $tests->{WINME}
                || $tests->{WINCE}
                || $tests->{WINPHONE}
        )
            || index( $ua, "win" ) != -1
    );

    $tests->{WINPHONE7}   = ( index( $ua, "windows phone os 7.0" ) != -1 );
    $tests->{WINPHONE7_5} = ( index( $ua, "windows phone os 7.5" ) != -1 );
    $tests->{WINPHONE8}   = ( index( $ua, "windows phone 8.0" ) != -1 );

    # Mac operating systems

    $tests->{MAC}
        = ( index( $ua, "macintosh" ) != -1 || index( $ua, "mac_" ) != -1 );
    $tests->{MACOSX} = ( index( $ua, "macintosh" ) != -1
            && index( $ua, "mac os x" ) != -1 );
    $tests->{MAC68K} = ( ( $tests->{MAC} )
            && ( index( $ua, "68k" ) != -1 || index( $ua, "68000" ) != -1 ) );
    $tests->{MACPPC}
        = (    ( $tests->{MAC} )
            && ( index( $ua, "ppc" ) != -1 || index( $ua, "powerpc" ) != -1 )
        );
    $tests->{IOS} = $tests->{IPAD} || $tests->{IPOD} || $tests->{IPHONE};

    # Others

    $tests->{AMIGA} = ( index( $ua, 'amiga' ) != -1 );

    $tests->{EMACS} = ( index( $ua, 'emacs' ) != -1 );
    $tests->{OS2}   = ( index( $ua, 'os/2' ) != -1 );

    if ( index( $ua, "samsung" ) < 0 ) {
        $tests->{SUN}  = ( index( $ua, "sun" ) != -1 );
        $tests->{SUN4} = ( index( $ua, "sunos 4" ) != -1 );
        $tests->{SUN5} = ( index( $ua, "sunos 5" ) != -1 );
        $tests->{SUNI86} = ( ( $tests->{SUN} ) && index( $ua, "i86" ) != -1 );
    }

    $tests->{IRIX}  = ( index( $ua, "irix" ) != -1 );
    $tests->{IRIX5} = ( index( $ua, "irix5" ) != -1 );
    $tests->{IRIX6} = ( index( $ua, "irix6" ) != -1 );

    $tests->{HPUX} = ( index( $ua, "hp-ux" ) != -1 );
    $tests->{HPUX9}  = ( ( $tests->{HPUX} ) && index( $ua, "09." ) != -1 );
    $tests->{HPUX10} = ( ( $tests->{HPUX} ) && index( $ua, "10." ) != -1 );

    $tests->{AIX}  = ( index( $ua, "aix" ) != -1 );
    $tests->{AIX1} = ( index( $ua, "aix 1" ) != -1 );
    $tests->{AIX2} = ( index( $ua, "aix 2" ) != -1 );
    $tests->{AIX3} = ( index( $ua, "aix 3" ) != -1 );
    $tests->{AIX4} = ( index( $ua, "aix 4" ) != -1 );

    $tests->{LINUX}    = ( index( $ua, "inux" ) != -1 );
    $tests->{SCO}      = $ua =~ m{(?:SCO|unix_sv)};
    $tests->{UNIXWARE} = ( index( $ua, "unix_system_v" ) != -1 );
    $tests->{MPRAS}    = ( index( $ua, "ncr" ) != -1 );
    $tests->{RELIANT}  = ( index( $ua, "reliantunix" ) != -1 );

    $tests->{DEC}
        = (    index( $ua, "dec" ) != -1
            || index( $ua, "osf1" ) != -1
            || index( $ua, "declpha" ) != -1
            || index( $ua, "alphaserver" ) != -1
            || index( $ua, "ultrix" ) != -1
            || index( $ua, "alphastation" ) != -1 );

    $tests->{SINIX}   = ( index( $ua, "sinix" ) != -1 );
    $tests->{FREEBSD} = ( index( $ua, "freebsd" ) != -1 );
    $tests->{BSD}     = ( index( $ua, "bsd" ) != -1 );
    $tests->{X11}     = ( index( $ua, "x11" ) != -1 );

    $tests->{CHROMEOS}
        = ( $tests->{X11} && index( $ua, "cros" ) != -1 );

    $tests->{UNIX}
        = ( !$tests->{CHROMEOS}
            && ($tests->{X11}
            || $tests->{SUN}
            || $tests->{IRIX}
            || $tests->{HPUX}
            || $tests->{SCO}
            || $tests->{UNIXWARE}
            || $tests->{MPRAS}
            || $tests->{RELIANT}
            || $tests->{DEC}
            || $tests->{LINUX}
            || $tests->{BSD} ) );

    $tests->{VMS}
        = ( index( $ua, "vax" ) != -1 || index( $ua, "openvms" ) != -1 );

    $tests->{ANDROID} = ( index( $ua, "android" ) != -1 );

    $tests->{FIREFOXOS}
        = (    $tests->{FIREFOX}
            && ( $tests->{MOBILE} || $tests->{TABLET} )
            && !$tests->{ANDROID}
            && index( $ua, "fennec" ) == -1 );

    $tests->{BB10}        = ( index( $ua, "bb10" ) != -1 );
    $tests->{RIMTABLETOS} = ( index( $ua, "rim tablet os" ) != -1 );

    $tests->{PS3GAMEOS} = $tests->{PS3} && $tests->{NETFRONT};
    $tests->{PSPGAMEOS} = $tests->{PSP} && $tests->{NETFRONT};
}

# undocumented, experimental, volatile. not bothering with major/minor here as
# that's flawed for 3 point versions the plan is to move this parsing into the
# UeberAgent parser

sub os_version {
    my $self = shift;

    if (   $self->ios
        && $self->{user_agent} =~ m{OS (\d*_\d*|\d*_\d*_\d*) like Mac} )
    {
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
        =~ m{Windows \s Phone \s \w{0,2} \s{0,1} (\d+\.\d+);}x )
    {
        return $1;
    }

    if ( $self->android && $self->{user_agent} =~ m{Android ([\d\.\w-]*)} ) {
        return $1;
    }

    if ( $self->firefoxos && $self->{user_agent} =~ m{Firefox/([\d\.]*)} ) {
        return $1;
    }
}

# because the internals are the way they are, these tests have to happen in a
# certain order.  hopefully we can change this once we have lazily loaded
# attributes.  in the meantime, a pile of returns will do the job.  if we
# changed this to use a hash, we'd still need a carefully ordered array of keys
# in order to get something useful back.  so, as it is, this actually wouldn't
# be that much less verbose and the order of operations is quite clear.  it
# still feels dirty, though.  it does highlight the fact that way too many
# methods can return true for some UA strings, which means there are probably a
# lot of false positives we haven't checked for.

sub browser_string {
    my ( $self ) = _self_or_default( @_ );
    return undef unless defined $self->{user_agent};

    return 'Netscape'      if $self->netscape;
    return 'IceWeasel'     if $self->iceweasel;
    return 'Firefox'       if $self->firefox;
    return 'BlackBerry'    if $self->blackberry;
    return 'Mobile Safari' if $self->mobile_safari;
    return 'RealPlayer'    if $self->realplayer_browser;
    return 'Safari'        if $self->safari;
    return 'Chrome'        if $self->chrome;
    return 'AOL Browser'   if $self->aol;
    return 'MSIE'          if $self->ie;
    return 'WebTV'         if $self->webtv;
    return 'Obigo'         if $self->obigo;
    return 'Nintendo DSi'  if $self->dsi;
    return 'Opera'         if $self->opera;
    return 'Mosaic'        if $self->mosaic;
    return 'Lynx'          if $self->lynx;
    return 'ELinks'        if $self->elinks;
    return 'Links'         if $self->links;
    return 'curl'          if $self->curl;
    return 'puf'           if $self->puf;
    return 'NetFront'      if $self->netfront;
    return 'Nintendo 3DS'  if $self->n3ds;
    return undef;
}

sub os_string {
    my ( $self ) = _self_or_default( @_ );
    return undef unless defined $self->{user_agent};

    return 'Win95'                       if $self->win95;
    return 'Win98'                       if $self->win98;
    return 'Win2k'                       if $self->win2k;
    return 'WinXP'                       if $self->winxp;
    return 'Win2k3'                      if $self->win2k3;
    return 'WinVista'                    if $self->winvista;
    return 'Win7'                        if $self->win7;
    return 'Win8'                        if $self->win8_0;
    return 'Win8.1'                      if $self->win8_1;
    return 'WinNT'                       if $self->winnt;
    return 'Windows Phone'               if $self->winphone;
    return 'Win3x'                       if $self->win3x;
    return 'Android'                     if $self->android;
    return 'Linux'                       if $self->linux;
    return 'Unix'                        if $self->unix;
    return 'Chrome OS'                   if $self->chromeos;
    return 'Firefox OS'                  if $self->firefoxos;
    return 'BlackBerry 10'               if $self->bb10;
    return 'RIM Tablet OS'               if $self->rimtabletos;
    return 'Playstation 3 GameOS'        if $self->ps3gameos;
    return 'Playstation Portable GameOS' if $self->pspgameos;
    return 'iOS'      if $self->iphone || $self->ipod || $self->ipad;
    return 'Mac OS X' if $self->macosx;
    return 'Mac'      if $self->mac;
    return 'OS2'      if $self->os2;
    return undef;
}

sub realplayer {
    my ( $self, $check ) = _self_or_default( @_ );

    return 1 if $self->{tests}->{REALPLAYER};
    return 0;
}

sub _realplayer_version {
    my ( $self, $check ) = _self_or_default( @_ );

    if ( exists $self->{realplayer_version}
        && $self->{realplayer_version} )
    {
        my @version = split( /\./, $self->{realplayer_version} );
        $self->{major}              = shift @version;
        $self->{minor}              = $self->_format_minor( shift @version );
        $self->{realplayer_version} = $self->{major} + $self->{minor};
        return $self->{realplayer_version};
    }

    return 0;
}

sub realplayer_browser {
    my ( $self, $check ) = _self_or_default( @_ );
    return 1 if $self->{realplayer_version};
    return 0;
}

sub gecko_version {
    my ( $self, $check ) = _self_or_default( @_ );
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
    my ( $self, $check ) = _self_or_default( @_ );

    return $self->_realplayer_version if $self->_realplayer_version;

    my $version = $self->{major} + $self->{minor};
    if ( defined $check ) {
        return $check == $version;
    }
    else {
        return $version;
    }
}

sub major {
    my ( $self, $check ) = _self_or_default( @_ );
    my ( $version ) = $self->{major};
    if ( defined $check ) {
        return $check == $version;
    }
    else {
        return $version;
    }
}

sub minor {
    my ( $self, $check ) = _self_or_default( @_ );
    my ( $version ) = $self->{minor};
    if ( defined $check ) {
        return ( $check == $self->{minor} );
    }
    else {
        return $version;
    }
}

sub public_version {
    my ( $self,  $check ) = _self_or_default( @_ );
    my ( $major, $minor ) = $self->_public;

    return $major + $minor;
}

sub public_major {
    my ( $self,  $check ) = _self_or_default( @_ );
    my ( $major, $minor ) = $self->_public;

    return $major;
}

sub public_minor {
    my ( $self,  $check ) = _self_or_default( @_ );
    my ( $major, $minor ) = $self->_public;

    return $minor;
}

sub public_beta {
    my ( $self, $check ) = _self_or_default( @_ );
    my ( $major, $minor, $beta ) = $self->_public;

    return $beta;
}

sub _public {
    my ( $self, $check ) = _self_or_default( @_ );

    # Return Public version of Safari. See RT #48727.
    if ( $self->safari ) {
        my $ua = lc $self->{user_agent};

        # Safari starting with version 3.0 provides its own public version
        if ($ua =~ m{
                version/
                ( \d+ )       # Major version number is everything before first dot
                ( \. \d+ )?   # Minor version number is first dot and following digits
            }x
            )
        {
            return ( $1, $2, undef );
        }

        # Safari before version 3.0 had only build numbers; use a lookup table
        # provided by Apple to convert to version numbers

        if ( $ua =~ m{ safari/ ( \d+ (?: \.\d+ )* ) }x ) {
            my $build   = $1;
            my $version = $safari_build_to_version{$build};
            unless ( $version ) {

                # if exact build -> version mapping doesn't exist, find next
                # lower build

                for my $maybe_build (
                    sort { $self->_cmp_versions( $b, $a ) }
                    keys %safari_build_to_version
                    )
                {
                    $version = $safari_build_to_version{$maybe_build}, last
                        if $self->_cmp_versions( $build, $maybe_build ) >= 0;
                }
            }
            my ( $major, $minor ) = split /\./, $version;
            my $beta;
            $minor =~ s/(\D.*)// and $beta = $1;
            $minor = 0 + ( '.' . $minor );
            return ( $major, $minor, ( $beta ? 1 : undef ) );
        }
    }

    return ( $self->major, $self->minor, $self->beta( $check ) );
}

sub _cmp_versions {
    my ( $self, $a, $b ) = @_;

    my @a = split /\./, $a;
    my @b = split /\./, $b;

    while ( @b ) {
        return -1 if @a == 0 || $a[0] < $b[0];
        return 1  if @b == 0 || $b[0] < $a[0];
        shift @a;
        shift @b;
    }

    return @a <=> @b;
}

sub engine_string {

    my ( $self, $check ) = _self_or_default( @_ );

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

    my ( $self, $check ) = _self_or_default( @_ );

    return $self->{engine_version};

}

sub engine_version {

    my ( $self, $check ) = _self_or_default( @_ );

    if ( $self->_engine ) {
        return $self->engine_major + $self->engine_minor;
    }

    return undef;

}

sub engine_major {

    my ( $self, $check ) = _self_or_default( @_ );

    if ( $self->_engine ) {
        my @version = split( /\./, $self->_engine );
        return shift @version;
    }

    return undef;

}

sub engine_minor {

    my ( $self, $check ) = _self_or_default( @_ );

    if ( $self->_engine ) {
        my @version = split( /\./, $self->_engine );
        shift @version;
        return $self->_format_minor( shift @version );
    }

    return undef;

}

sub beta {
    my ( $self, $check ) = _self_or_default( @_ );
    my ( $version ) = $self->{beta};
    if ( $check ) {
        return $check eq $version;
    }
    else {
        return $version;
    }
}

sub language {

    my ( $self, $check ) = _self_or_default( @_ );
    my $parsed = $self->_language_country();
    return $parsed->{'language'};

}

sub country {

    my ( $self, $check ) = _self_or_default( @_ );
    my $parsed = $self->_language_country();
    return $parsed->{'country'};

}

sub device {

    my ( $self, $check ) = _self_or_default( @_ );

    foreach my $device ( sort keys %DEVICE_TESTS ) {
        return $device if ( $self->$device );
    }

    return undef;
}

sub device_name {

    my ( $self, $check ) = _self_or_default( @_ );

    return $self->{device_name} if defined $self->{device_name};

    my $device = $self->device;
    return undef if !$device;

    return $DEVICE_TESTS{ $self->device };
}

sub _language_country {

    my ( $self, $check ) = _self_or_default( @_ );

    if ( $self->safari ) {
        if (   $self->major == 1
            && $self->{user_agent} =~ m/\s ( [a-z]{2} ) \)/xms )
        {
            return { language => uc $1 };
        }
        if ( $self->{user_agent} =~ m/\s ([a-z]{2})-([A-Za-z]{2})/xms ) {
            return { language => uc $1, country => uc $2 };
        }
    }

    if (   $self->aol
        && $self->{user_agent} =~ m/;([A-Z]{2})_([A-Z]{2})\)/ )
    {
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
        foreach my $part ( @parts ) {
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

    my ( $self, $check ) = _self_or_default( @_ );

    my @browser_properties;
    foreach my $property ( sort keys %{ $self->{tests} } ) {
        push @browser_properties, lc( $property )
            if ( ${ $self->{tests} }{$property} );
    }

    # devices are a property too but it's not stored in %tests
    # so I explicitly test for it and add it
    push @browser_properties, 'device' if ( $self->device() );

    return @browser_properties;
}

sub robot_name {
    my $self = shift;
    foreach my $name ( @ROBOT_TESTS ) {
        next if $name eq 'robot';
        if ( $self->$name ) {
            return $ROBOTS{$name};
        }
    }
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
    print $browser->mac;

    # Detect browser vendor and version
    print $browser->netscape;
    print $browser->ie;
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

You may also use a non-object-oriented interface. For each method, you may call
HTTP::BrowserDetect::method_name(). You will then be working with a default
HTTP::BrowserDetect object that is created behind the scenes.

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
Currently returns one of: android, audrey, blackberry, dsi, iopener, ipad,
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

Returns the browser version as a floating-point number.

=head2 public_major()

Returns the integer portion of the browser version.

=head2 public_minor()

Returns the decimal portion of the browser version as a B<floating-point
number> less than 1. For example, if the version is 4.05, this method returns
.05; if the version is 4.5, this method returns .5.

On occasion a version may have more than one decimal point, such as
'Wget/1.4.5'. The minor version does not include the second decimal point, or
any further digits or decimals.

=head2 version($version)

This is probably not what you want.  Please use either public_version() or
engine_version() instead.

Returns the version as a floating-point number. If passed a parameter, returns
true if it is equal to the version specified by the user agent string.

=head2 major($major)

This is probably not what you want.  Please use either public_major() or
engine_major() instead.

Returns the integer portion of the browser version. If passed a parameter,
returns true if it equals the browser major version.

=head2 minor($minor)

This is probably not what you want.  Please use either public_minor() or
engine_minor() instead.

Returns the decimal portion of the browser version as a B<floating-point
number> less than 1. For example, if the version is 4.05, this method returns
.05; if the version is 4.5, this method returns .5. B<This is a change in
behavior from previous versions of this module, which returned a string>.

If passed a parameter, returns true if equals the minor version.

On occasion a version may have more than one decimal point, such as
'Wget/1.4.5'. The minor version does not include the second decimal point, or
any further digits or decimals.

=head2 beta($beta)

Returns any the beta version, consisting of any non-numeric characters after
the version number. For instance, if the user agent string is 'Mozilla/4.0
(compatible; MSIE 5.0b2; Windows NT)', returns 'b2'. If passed a parameter,
returns true if equal to the beta version. If the beta starts with a dot, it
is thrown away.


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

  Win95, Win98, WinNT, Win2K, WinXP, Win2k3, WinVista, Win7, Win8,
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

=head3 ie ie3 ie4 ie4up ie5 ie55 ie6 ie7 ie8 ie9 ie10 ie11

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

=head3 realplayer_browser

The realplayer method above tests for the presence of either the RealPlayer
plug-in "(r1 " or the browser "RealPlayer". To preserve "bugwards
compatibility" and prevent false reporting, browser_string calls this method
which ignores the "(r1 " plug-in signature.

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
BlackBerry.

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
