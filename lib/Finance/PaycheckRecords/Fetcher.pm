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
use URI ();
use URI::QueryParam ();         # part of URI; has no version number
use WWW::Mechanize ();

=head1 DEPENDENCIES

Finance::PaycheckRecords::Fetcher requires
{{$t->dependency_link('File::Slurp')}},
{{$t->dependency_link('LWP::UserAgent')}},
{{$t->dependency_link('URI')}}, and
{{$t->dependency_link('WWW::Mechanize')}}.

=cut

#=====================================================================

=method new

  $fetcher = Finance::PaycheckRecords::Fetcher->new(
               $username, $password
             );

This constructor creates a new Finance::PaycheckRecords::Fetcher
object.  C<$username> and C<$password> are your login information for
PaycheckRecords.com.

=cut

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
# Get a URL, automatically supplying login credentials if needed:

sub _get
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

  die unless $mech->success;    # FIXME
} # end _get

#---------------------------------------------------------------------
sub listURL { 'https://www.paycheckrecords.com/in/paychecks.jsp' }

=for Pod::Coverage
listURL

=method available_paystubs

  $paystubs = $fetcher->available_paystubs;

This connects to PaycheckRecords.com and downloads a list of available
paystubs.  It returns a hashref where the keys are paystub dates in
YYYY-MM-DD format and the values are L<URI> objects to the
printer-friendly paystub for that date.

Currently, it lists only the paystubs shown on the initial page after
you log in.  For me, this is the last 6 paystubs.

=cut

sub available_paystubs
{
  my ($self) = @_;

  $self->_get( $self->listURL );

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

=method mirror

  @new_paystubs = $fetcher->mirror;

This connects to PaycheckRecords.com and downloads all paystubs listed
by C<available_paystubs> that haven't already been downloaded.  It
returns a list of filenames of newly downloaded paystubs, or the empty
list if there are no new paystubs.  Each paystub is saved to the
current directory under the name F<Paycheck-YYYY-MM-DD.html>.  If a
file by that name already exists, then it assumes that paystub has
already been downloaded (and is not included in the return value).

In scalar context, it returns the number of paystubs downloaded.

=cut

sub mirror
{
  my ($self) = @_;

  my $mech = $self->{mech};

  my $stubs = $self->available_paystubs;

  my @fetched;

  foreach my $date (sort keys %$stubs) {
    my $fn = "Paycheck-$date.html";
    next if -e $fn;
    $self->_get($stubs->{$date});
    File::Slurp::write_file( $fn, {binmode => ':utf8'}, $mech->content );
    push @fetched, $fn;
  }

  @fetched;
} # end mirror

#=====================================================================
# Package Return Value:

1;

__END__

=for Pod::Loom-sort_method
new

=head1 SYNOPSIS

  use Finance::PaycheckRecords::Fetcher;

  my $fetcher = Finance::PaycheckRecords::Fetcher->new(
    $username, $password
  );

  my @fetched = $fetcher->mirror;


=head1 DESCRIPTION

Finance::PaycheckRecords can download paystubs from
PaycheckRecords.com, so you can save them for your records.  You can
use L<Finance::PaycheckRecords> (available separately) to extract
information from the stored paystubs.


=head1 SEE ALSO

L<Finance::PaycheckRecords> can be used to extract information from
the downloaded paystubs.


=head1 BUGS AND LIMITATIONS

L</available_paystubs> is limited to those displayed by default when
you log in to PaycheckRecords.com.  There's currently no way to select
a different date range.  Since L</mirror> uses C<available_paystubs>,
the same limitation applies.
