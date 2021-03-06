package Viyond::Action::Search;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Status;
use JSON;

use Term::ANSIColor qw/:constants/;

use Try::Tiny;
use Data::Util qw/:check/;
use feature qw/say/;

use Viyond::Config;
use Viyond::InstallData::Metadata;
use Viyond::Action::Install;


sub search {
  my ($class, $url) = @_;

  my $ua = LWP::UserAgent->new;
  $ua->agent('Viyond');
  $ua->timeout(15);
  my $req = HTTP::Request->new(GET => $url);
  my $res;

  try {
    local $SIG{ALRM} = sub { die; };
    alarm 15;
    $res= $ua->request($req);
    alarm 0;
  } catch {
    say "response time could too long. longer query word might help.";
    return;
  };

  if ($res->is_success) {
    my $json = decode_json($res->content);
    my $repositories = $json->{repositories};

    if ( is_array_ref($repositories) ) {
      $repositories = [sort { $b->{followers} <=> $a->{followers} } @{$json->{repositories}}];
      my $repos_num = $class->print_repos($repositories);

      return if $repos_num == 0;
      $class->run_term($repositories, $repos_num);
    }
    else {
      say "github response includes error, please try it again after a while: $json->{error}->{error}";
      last;
    }
  }
  else {
    say "http response had error: code $res->code";
  }
}

sub print_repos {
  my ($class, $repositories) = @_;

  return 0 if scalar @$repositories == 0;

  my @installed_repo_ids = keys %{Viyond::InstallData::Metadata->load_all};

  $Term::ANSIColor::AUTORESET = 1;
  my $repos_num = 1;

  for my $repository (@$repositories) {

    next if $repository->{name} =~ /^\.?vim$|(dot|vim)files|dotvim|conf(ig)?/i;

    print BOLD WHITE ON_BLUE $repos_num;
    print " ";
    print BOLD WHITE "$repository->{username}/";
    print BOLD CYAN $repository->{name};
    if ( grep { $_ eq "$repository->{name}-$repository->{id}" } @installed_repo_ids ) {
      print " ";
      print BOLD WHITE ON_MAGENTA "[installed]";
    }
    print " ";
    print "(";
    print BOLD GREEN "followers: ";
    print "$repository->{followers},";
    print " ";
    print BOLD GREEN "pushed: ";
    $repository->{pushed} =~ s/T.*$//;
    print "$repository->{pushed},";
    print " ";
    print BOLD GREEN "url: ";
    print "http://github.com/$repository->{username}/$repository->{name}";
    print ")";
    print "\n";
    print " " x 6;
    print $repository->{description};
    print "\n";
    $repos_num++;
  }

  print "\n";
  print BOLD YELLOW "==> ";
  print BOLD WHITE "Enter n (seperated by blanks) of vim plugins to be installed\n";
  print BOLD YELLOW "==> ";

  return $repos_num;
}

sub run_term {
  my ($class, $repositories, $repos_num) = @_;

  my $command = <STDIN>;
  my @numbers = split / /, $command;

  for my $number (@numbers) {
    if ( $number =~ /\d+/ && grep { $_ == $number } ( 1 .. $repos_num ) ) {
      Viyond::Action::Install->install($repositories->[$number - 1]);
      print "\n";
    }
  }
}

1;
