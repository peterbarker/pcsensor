package FindTempers;

use strict;
use warnings;

use DirHandle qw ();
use FileHandle qw ();
use POSIX qw ( O_RDONLY );

package Temper;

# we'll use this later...
1;


package FindTempers;

sub slurp {
  my ($filename) = @_;

  my $fh = FileHandle->new($filename,O_RDONLY) or
    die "Failed to open ($filename): $!";

  local $/ = undef;
  my $content = <$fh>;
  $content;
}
sub find_devices_by_idVendor_and_idProduct {
  my ($class,$basepath,$idVendor,$idProduct) = @_;
  my $dh = DirHandle->new($basepath) or
    die "Failed to open ($basepath): $!";

  my @entries = ();
  DEVICE: while (my $entry = $dh->read()) {
    next if $entry eq '.';
    next if $entry eq '..';
    next unless $entry =~ /^(\d+)-([0-9.]+)$/;
#    print "$entry\n";

    my $path = "$basepath/$entry";
    {
      my $this_idVendor = &slurp("$path/idVendor");
      chomp $this_idVendor;
      next DEVICE unless $this_idVendor eq $idVendor;
    }

    {
      my $this_idProduct = &slurp("$path/idProduct");
      chomp $this_idProduct;
      next DEVICE unless $this_idProduct eq $idProduct;
    }
#    print STDERR "Found it ($entry)\n";
    push @entries, $entry;
  }

  return @entries;
}

sub bus_id_and_device_id_for_device_name {
  my ($class,$device_name) = @_;

  
}

my $temperA = bless {
  idVendor => '0c45',
  idProduct => '7401',
  name => 'Temper A',
  location => 'On Monitor',
}, 'Temper';
my $temperB = bless {
  idVendor => '0c45',
  idProduct => '7401',
  name => 'Temper B',
  location => 'On Desk',
}, 'Temper';

my $device_tree = {
  3 => $temperA,
  4 => $temperB,
};

my $basepath ="/sys/bus/usb/devices";

my $hub_idVendor = '05e3';
my $hub_idProduct = '0608';
sub find_tempers {
  my ($class) = @_;

  my @devices = $class->find_devices_by_idVendor_and_idProduct($basepath,$hub_idVendor,$hub_idProduct);
#  print STDERR "Got (@devices)\n";
  die "Found more than one device matching Vendor/Product $hub_idVendor:$hub_idProduct)" if @devices > 1;
  if (not @devices) {
    die "No deice with Vendor/Product $hub_idVendor:$hub_idProduct found";
  }

  my $device = $devices[0];
  if (not &match_device_against_tree($basepath,$device,$device_tree)) {
    die "unable to match device ($device) against device tree";
  }

  my @pairs = &bus_and_dev_nums_from_for_device_and_tree($basepath,$device,$device_tree);
  foreach my $pair (@pairs) {
    my ($busnum,$devicenum) = @$pair;
    print "$busnum $devicenum\n";
  }
}

sub bus_and_dev_nums_from_for_device_and_tree {
  my ($basepath,$device,$tree) = @_;

  if (! -e "$basepath/$device") {
    print STDERR "Whoops - no $basepath/$device\n";
    return ();
  }

  my @pairs = ();
  foreach my $key (keys %$tree) {
    my $path = "$device.$key";
    if (ref($tree->{$key}) eq 'Temper') {
#      print STDERR "Found temper $tree->{$key}->{name} @ $path\n";
      if (not -e "$basepath/$path") {
	print STDERR "$basepath/$path does not exist\n";
	next;
      }
      my $content = &slurp("$basepath/$path/idProduct");
#      print STDERR "$basepath/$path/idProduct content=$content\n";
      my $devnum = &slurp("$basepath/$path/devnum");
      chomp $devnum;
      my $busnum = &slurp("$basepath/$path/busnum");
      chomp $busnum;
#      print "$busnum $devnum\n";
      push @pairs,[$busnum,$devnum];
      next;
    }
    push @pairs, &bus_and_dev_nums_from_for_device_and_tree($basepath,$path,$tree->{$key});
  }

  return @pairs;
}
# sub walk_tree {
#   my ($basepath,$device,$tree) = @_;
#   if (! -e "$basepath/$device") {
#     print STDERR "Whoops - no $basepath/$device\n";
#     return 0;
#   }
# }

sub match_device_against_tree {
  my ($basepath,$device,$tree) = @_;
  if (! -e "$basepath/$device") {
    print STDERR "Whoops - no $basepath/$device\n";
    return 0;
  }
  foreach my $key (keys %$tree) {
    my $path = "$device.$key";
    if (ref($tree->{$key}) eq 'Temper') {
#      print STDERR "Found temper $tree->{$key}->{name} @ $path\n";
      if (not -e "$basepath/$path") {
	print STDERR "$basepath/$path does not exist\n";
	next;
      }
      my $content = &slurp("$basepath/$path/idProduct");
#      print STDERR "$basepath/$path/idProduct content=$content\n";

      next;
    }
    &match_device_against_tree($basepath,$path,$tree->{$key});
  }

  return 1;
}

1;
