#!/usr/bin/perl -w

use strict;
use Data::Dumper;

my $todotxt = '/usr/local/bin/todo.sh';
my $debug = 0;
my $debug_todo_conf = '';
my $disable_smart_uppercase = 0;
my $fancy_icons = 0;
my $icondir = 'icons';
my $confmsg = 'Configure the workflow';

my $idfilter = 0;
my $config = $ENV{HOME} . '/.alfred-todo.conf';
my %config = ();
my @out = ();

sub debug {
    return if not $debug;
    print STDERR 'DEBUG: ', @_, "\n";
}

sub loadconf($) {
    my $force = shift;
    if (not -f $config) {
        return () if not $force;
        print STDERR "Creating config file: $config\n";
        open(CONF, '>', $config) or die "Unable to create file: $config";
        print CONF <<EOF;
##                              ##
## ALFRED-TODO.CONF:VERSION=1.1 ##
##                              ##

# Path to the todo_txt binary
#TODO_TXT = /usr/local/bin/todo.sh

# Uncomment to disable automatic uppercasing of first letters in new tasks
#DISABLE_SMART_UPPERCASE = 1

# Uncomment to enable fancy icons. The default is to use simple icons.
#FANCY_ICONS = 1

EOF
        close CONF;
        return ();
    }
    open(CONF, $config) or die "Unable to open config file: $config";
    while (<CONF>) {
        next if not /^\s*(\w+?)\s*=\s*(.+?)\s*$/;
        $config{$1} = $2;
    }
    close CONF;
}

my $__filecheck = 0;
sub getconf($;%) {
    my ($key, $p) = @_;
    debug "Trying to get config parameter: $key";
    my $errmsg = $p->{errmsg};
    my $force = $p->{force};
    if (not exists $config{$key}) {
        # Try loading the config file if not loaded yet
        return '' if $__filecheck and not $force and not $errmsg;
        debug "Trying to load config file";
        $__filecheck = 1;
        loadconf($force || $errmsg);
    }
    if (not exists $config{$key}) {
        if ($errmsg) {
            # Throw up error in Alfred
            print geterrxml($errmsg,
                            "Please fix this in config file: $config");
            exit 0;
        }
        return '';
    }
    if ($config{$key} =~ m#^~/(.*)#) {
        $config{$key} = $ENV{HOME} . '/' . $1;
    }
    return $config{$key};
}

sub getlist {
    my $searchstr = join(' ', grep defined, @_);
    debug "Search string: $searchstr" if $searchstr;

    my @out = ();
    my $comm = "$todotxt -f -p ls $searchstr";
    open(COMM, "$comm |")
        or die "Error running command: $comm\n";
    while (<COMM>) {
        chomp;
        last if /^--$/;
        if (not /^0*(\d+) (?:\(([A-Z])\)\s)?(.*)/) {
            warn "Unable to parse line: $_\n";
            next;
        }
        next if $idfilter and $1 != $idfilter;
        push(@out, {
                id => $1,
                pri => $2,
                desc => $3,
            });

    }
    close COMM;
    return \@out;
}

sub getcompletions($) {
    my $prefix = shift;
    my $type = substr($prefix, 0, 1);
    my %comms = (
        '+' => 'lsprj',
        '@' => 'lsc',
    );
    return () if not exists $comms{$type};
    my $comm = $todotxt . ' ' . $comms{$type};
    my $projre = qr/^\Q$prefix\E/;
    my @out = ();
    if (open(COMM, "$comm |")) {
        while (<COMM>) {
            chomp;
            push(@out,$_) if /$projre/;
        }
        close COMM;
    }
    return @out;
}

sub pushin($) {
    my $listref = shift;
    push(@out, @$listref);
    return \@out;
}

sub getxml($) {
    my $p = shift;
    my $arg = $p->{arg};
    my $title = $p->{title};
    my $subtitle = $p->{subtitle};
    my $icon = $p->{icon};
    my $valid = (exists $p->{valid} ? $p->{valid} : 'YES');
    my $autocomplete = (exists $p->{autocomplete} ? $p->{autocomplete} : '');
    return <<XML;
    <item arg="$arg" valid="$valid" autocomplete="$autocomplete">
        <title>$title</title>
        <subtitle>$subtitle</subtitle>
        <icon>$icon</icon>
    </item>
XML
}

sub geterrxml($$) {
    my ($title, $subtitle) = @_;
    return <<ERRXML;
<?xml version="1.0"?>
<items>
<item valid="NO">
  <title>$title</title>
  <subtitle>$subtitle</subtitle>
  <icon>erricon.png</icon>
</item>
<items>
ERRXML
}

sub geticon($) {
    my $pri = shift;
    if ($pri) {
        $pri = uc $pri;
        return "$icondir/$pri.png";
    } else {
        return "$icondir/NONE.png";
    }
}

my $output_gen = {
    'add' => sub {
        my $item = shift;
        my $comm = ($item->{pri} ? "--do addpri $item->{pri} " : '--do add ')
            . $item->{desc};
        my $valid = ($item->{valid} ? $item->{valid} : 'YES');
        my $autocomplete = ($item->{autocomplete} ? $item->{autocomplete} : '');
        my $subtitle = "Add Task"
            . ($item->{pri} ? ' with Priority (' . uc($item->{pri}) . ')' : '');
        return getxml({
                arg => $comm,
                title => $item->{desc},
                subtitle => $subtitle,
                icon => "$icondir/ADD.png",
                valid => $valid,
                autocomplete => $autocomplete,
            });
    },
    'do' => sub {
        my $item = shift;
        my $id = $item->{id};
        my $comm = "--do do $id";
        return getxml({
                arg => $comm,
                title => "[$id] " . $item->{desc},
                subtitle => "Mark Task as Done",
                icon => geticon($item->{pri}),
            });
    },
    'preppri' => sub {
        my $item = shift;
        my $id = $item->{id};
        my $comm = "pri $id";
        return getxml({
                arg => $comm,
                title => "[$id] " . $item->{desc},
                subtitle => "Set Priority to ...",
                icon => "$icondir/SET.png",
                valid => 'NO',
                autocomplete => 'pri ' . $item->{id} . ' ',
            });
    },
    'pri' => sub {
        my $item = shift;
        my $id = $item->{id};
        my $comm = "--do pri $id " . $item->{newpri};
        return getxml({
                arg => $comm,
                title => "[$id] " . $item->{desc},
                subtitle => 'Set Priority to (' . $item->{newpri} . ')',
                icon => geticon($item->{newpri}),
            });
    },
    'conf' => sub {
        return getxml({
                arg => '--create-conf',
                title => $confmsg,
                subtitle => "Open config file: $config",
                icon => "$icondir/NONE.png",
            });
    },
};

sub output($) {
    my $outref = shift;
    print STDERR Data::Dumper->Dump([$outref], [qw(*OUT)]) if $debug > 1;

    print '<?xml version="1.0"?><items>';
    foreach my $item (@$outref) {
        my $action = $item->{action};
        die "ERROR: Unknown action: $action"
            if not exists $output_gen->{$action};
        print $output_gen->{$action}->($item);
    }
    print "</items>\n";
}

# Actions
sub addact($$) {
    my ($listref, $action) = @_;
    map { $_->{action} = $action } @$listref;
    return $listref;
}

sub addpri($$) {
    my ($listref, $pri) = @_;
    map { $_->{newpri} = uc $pri } @$listref;
    return $listref;
}

sub add($) {
    return addact($_[0], 'add');
}

sub done($) {
    return addact($_[0], 'do');
}

sub pri($;$) {
    my ($desc, $pri) = @_;
    if ($pri) {
        return addpri(addact($_[0], 'pri'), $pri);
    } else {
        return addact($_[0], 'preppri');
    }
}

#
# Main
#
$debug = getconf('DEBUG');
$debug_todo_conf = getconf('DEBUG_TODO_CONF');

my $conf_todotxt = getconf('TODO_TXT');
$todotxt = $conf_todotxt if $conf_todotxt;
if (not -x $todotxt) {
    $todotxt = getconf('TODO_TXT', {
        errmsg => 'Configure TODO_TXT parameter in config file',
    });
    if (not -x $todotxt) {
        print geterrxml('Fix TODO_TXT parameter in config file',
                        "Configured path is invalid: $todotxt");
        exit 0;
    }
}

$debug = 0 if not $debug;
$todotxt .= " -d $debug_todo_conf" if $debug and $debug_todo_conf;

$disable_smart_uppercase = getconf('DISABLE_SMART_UPPERCASE');
$fancy_icons = getconf('FANCY_ICONS');
$icondir .= '/fancy' if $fancy_icons;

my $arg = join(' ', @ARGV);
debug "Command: $0 $arg";

# If a "--do" command, perform action
if ($arg =~ /^--do\s+(.*?)\s+(.*)/ or
        $arg =~ /^(del)\s.*?(\d+)$/) {
    my $act = $1;
    my $param = $2;
    my $pri;
    if ($act eq 'addpri') {
        $act = 'add';
        ($pri, $param) = split(' ', $param, 2);
    }
    debug "Performing action: $todotxt -f $act $param";
    my $out = `$todotxt -f $act $param`;
    if (not $pri) {
        print $out;
        exit 0;
    }
    if ($out =~ /^(\d+)\s/) {
        my $id = $1;
        debug "Performing action: $todotxt -f pri $id $pri";
        system("$todotxt -f pri $id $pri");
    } else {
        print "Failed to set priority. $out";
    }
    exit 0;
}

# If a "--create-conf" command, create config file
if ($arg =~ /^--create-conf/) {
    loadconf(1);
    debug "Creating/opening config file";
    system("open -a /Applications/TextEdit.app $config");
    exit 0;
}

# If a "--pick=<id>" command, pick just the specified ID
if ($arg =~ /^--pick=(\d+)\s*(.*)/) {
    debug "Picking ID: $1";
    $idfilter = $1;
    $arg = $2;
}

if (not $arg) {
    pushin(add([{
                    desc => 'Just keep typing to add a new TODO task',
                    valid => 'NO',
                }]));
    pushin(done(getlist()));
    exit 0;
}

if ($arg =~ /^conf/i and $confmsg =~ /\Q$arg\E/i) {
    debug "Including configure action";
    pushin([{ action => 'conf' }]);
}

my ($comm, $rest) = split(' ', $arg, 2);

if ($comm =~ /^(?:p|pr|pri)$/) {
    my $pri = '';
    debug "Potential priority change: $rest" if $rest;
    if ($rest and $rest =~ /^(?:(.*?)\s+)?([A-Za-z])$/) {
        $rest = $1;
        $pri = $2;
        debug "Task has new priority specified: $pri";
    }
    $idfilter = $1 if $rest and $rest =~ /^\s*(\d+)\s*$/;
    pushin(pri(getlist(($idfilter ? '' : $rest)), $pri));
} elsif ($rest =~ /(.*)\!([a-z]?)$/i) {
    $rest = "$comm $1";
    my $pri = $2;
    debug "Potential priority change: $pri";
    pushin(pri(getlist($rest), $pri));
} else {
    debug "Adding all tasks having the term: '$arg'";
    pushin(done(getlist($arg)));
}

# Last resort -- new task(s)
my $desc = $arg;
$desc =~ s/^./\U$&/ unless $disable_smart_uppercase;
if (not $idfilter) {
    if ($desc =~ /(.*?)\s+\!([a-zA-Z])$/) {
        pushin(add([{ desc => $1, pri => $2 }]));
    }
    pushin(add([{ desc => $desc }]));
}

if ($desc =~ /(.*?)\s+([\+\@]\w*)$/) {
    debug "Trying to autocomplete known projects/contexts for $2";
    my $prefix = $1;
    my $projprefix = $2;
    foreach my $proj (getcompletions($projprefix)) {
        pushin(add([{
                        desc => "$prefix $proj",
                        valid => 'NO',
                        autocomplete => "$prefix $proj ",
                    }]));
    }
}

END {
    output(\@out) if @out;
}
