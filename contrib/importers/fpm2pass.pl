#!/usr/bin/perl

# Copyright (C) 2012 Jeffrey Ratcliffe <jeffrey.ratcliffe@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

use warnings;
use strict;
use XML::Simple;
use Getopt::Long;
use Pod::Usage;

my ($help, $man);
my @args = ('help'         => \$help,
            'man'          => \$man,);
GetOptions (@args) or pod2usage(2);
pod2usage(1) if ($help);
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(
 -msg  => "Syntax error: must specify a file to read.",
 -exitval => 2,
 -verbose => 1
)
 if (@ARGV != 1);

# Grab the XML to a perl structure
my $xs = XML::Simple->new();
my $doc = $xs->XMLin(shift);

for (@{$doc->{PasswordList}{PasswordItem}}) {
  my $name;
  if (ref($_->{category}) eq 'HASH') {
    $name = escape($_->{title});
  }
  else {
    $name = escape($_->{category})."/".escape($_->{title});
  }
  my $contents = '';
  $contents .= "$_->{password}\n" unless (ref($_->{password}) eq 'HASH');
  $contents .= "user $_->{user}\n" unless (ref($_->{user}) eq 'HASH');
  $contents .= "url $_->{url}\n" unless (ref($_->{url}) eq 'HASH');
  unless (ref($_->{notes}) eq 'HASH') {
    $_->{notes} =~ s/\n/\n /g;
    $contents .= "notes:\n $_->{notes}\n";
  }
  my $cmd = "pass insert -f -m $name";
  my $pid = open(my $fh, "| $cmd") or die "Couldn't fork: $!\n";
  print $fh $contents;
  close $fh;
}

# escape inverted commas, spaces, ampersands and brackets
sub escape {
  my ($s) = @_;
  $s =~ s/\//-/g;
  $s =~ s/(['\(\) &])/\\$1/g;
  return $s;
}

=head1 NAME

 fpm2pass.pl - imports an .xml exported by fpm2 into pass

=head1 SYNOPSIS

=head1 USAGE

 fpm2pass.pl [--help] [--man] <xml>

The following options are available:

=over

=item --help

=item --man

=back

=cut
