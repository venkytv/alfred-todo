#!/usr/bin/perl -w

use strict;
use Data::Dumper;

# CUSTOMISE THIS PATH
my $todotxt = '/usr/local/bin/todo.sh';

my $debug = 1;
$todotxt .= " -d " . $ENV{HOME} . '/tmp/todo.cfg' if $debug;
my $idfilter = 0;

my @out = ();

sub debug {
    return if not $debug;
    print STDERR 'DEBUG: ', @_, "\n";
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

sub geticon($) {
    my $pri = shift;
    if ($pri) {
        $pri = uc $pri;
        return "icons/$pri.png";
    } else {
        return 'icons/NONE.png';
    }
}

my $output_gen = {
    'add' => sub {
        my $item = shift;
        my $comm = '--do add ' . $item->{desc};
        return getxml({
                arg => $comm,
                title => $item->{desc},
                subtitle => 'Add Task',
                icon => 'icons/ADD.png',
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
                icon => 'icons/SET.png',
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

my $arg = join(' ', @ARGV);
debug "Command: $0 $arg";

# If a "--do" command, perform action
if ($arg =~ /^--do\s+(.*)()/ or
        $arg =~ /^(del)\s.*?(\d+)$/) {
    debug "Performing action: $todotxt -f $1 $2";
    system("$todotxt -f $1 $2");
    exit 0;
}

# If a "--pick=<id>" command, pick just the specified ID
if ($arg =~ /^--pick=(\d+)\s*(.*)/) {
    debug "Picking ID: $1";
    $idfilter = $1;
    $arg = $2;
}

if (not $arg) {
    pushin(done(getlist()));
    exit 0;
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
} else {
    debug "Adding all tasks having the term: '$arg'";
    pushin(done(getlist($arg)));
}

# Last resort -- new task(s)
(my $desc = $arg) =~ s/^./\U$&/;
debug "ID filter: $idfilter";
pushin(add([{ desc => $desc }])) if not $idfilter;

END {
    output(\@out) if @out;
}
