#---------------------------------------------------------------------
package Finance::PaycheckRecords::Fetcher;
#
# Copyright 2013 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 4 Feb 2013
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Fetch paystubs from PaycheckRecords.com
#---------------------------------------------------------------------

use 5.010;
use strict;
use warnings;

our $VERSION = '0.01';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

use File::Slurp ();
use LWP::UserAgent 6 ();        # SSL certificate validation
use WWW::Mechanize ();
use URI::QueryParam ();

#=====================================================================

sub new
{
  my ($class, $user, $password) = @_;

  bless {
    username => $user,
    password => $password,
    mech     => WWW::Mechanize->new,
  }, $class;
} # end new

#---------------------------------------------------------------------
sub get
{
  my ($self, $url) = @_;

  my $mech = $self->{mech};

  $mech->get($url);

  if ($mech->form_name('Login_Form')) {
    $mech->set_fields(
      userStrId => $self->{username},
      password  => $self->{password},
    );
    $mech->click('Login', 5, 4);
    die "Login failed" if $mech->form_name('Login_Form');
  }

  die unless $mech->success;
} # end get

#---------------------------------------------------------------------
sub listURL { 'https://www.paycheckrecords.com/in/paychecks.jsp' }

sub available_paystubs
{
  my ($self) = @_;

  $self->get( $self->listURL );

  my @links = $self->{mech}->find_all_links(
    url_regex => qr!/in/paystub_printerFriendly\.jsp!
  );

  my %stub;

  for my $link (@links) {
    my $url = $link->url_abs;

    $stub{ $url->query_param('date') // die "Expected date= in $url" }
        = $url;
  }

  \%stub;
} # end available_paystubs

#---------------------------------------------------------------------
sub mirror
{
  my ($self) = @_;

  my $mech = $self->{mech};

  my $stubs = $self->available_paystubs;

  my @fetched;

  foreach my $date (sort keys %$stubs) {
    my $fn = "Paycheck-$date.html";
    next if -e $fn;
    $self->get($stubs->{$date});
    File::Slurp::write_file( $fn, {binmode => ':utf8'}, $mech->content );
    push @fetched, $fn;
  }

  @fetched;
} # end mirror

#=====================================================================
# Package Return Value:

1;

__END__

=head1 SYNOPSIS

  use Finance::PaycheckRecords::Fetcher;
