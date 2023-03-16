#
# Copyright 2023 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package snmp_standard::mode::listdiskiodevice;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my $oid_diskIODevice = '.1.3.6.1.4.1.2021.13.15.1.1.2';

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => { 
        'diskiodevice:s'              => { name => 'diskiodevice' },
        'name'                    => { name => 'use_name' },
        'regexp'                  => { name => 'use_regexp' },
        'regexp-isensitive'       => { name => 'use_regexpi' },
        'display-transform-src:s' => { name => 'display_transform_src' },
        'display-transform-dst:s' => { name => 'display_transform_dst' },
        'skip-total-size-zero'    => { name => 'skip_total_size_zero' }
    });

    $self->{diskiodevice_id_selected} = [];

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub run {
    my ($self, %options) = @_;
    $self->{snmp} = $options{snmp};

    $self->manage_selection();
    my $result = $self->get_additional_information();

    foreach (sort @{$self->{diskiodevice_id_selected}}) {
        my $display_value = $self->get_display_value(id => $_);
        
        $self->{output}->output_add(long_msg => "'" . $display_value . "' [id = " . $_ . ']');
    }

    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List disk IO device:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub get_additional_information {
    my ($self, %options) = @_;

    if (!defined($self->{option_results}->{skip_total_size_zero})) {
        return undef;
    }
    
    $self->{snmp}->load(instances => $self->{diskiodevice_id_selected});
    return $self->{snmp}->get_leef();
}

sub get_display_value {
    my ($self, %options) = @_;
    my $value = $self->{datas}->{'diskIODevice_' . $options{id}};

    if (defined($self->{option_results}->{display_transform_src})) {
        $self->{option_results}->{display_transform_dst} = '' if (!defined($self->{option_results}->{display_transform_dst}));
        eval "\$value =~ s{$self->{option_results}->{display_transform_src}}{$self->{option_results}->{display_transform_dst}}";
    }
    return $value;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{datas} = {};
    my $result = $self->{snmp}->get_table(oid => $oid_diskIODevice);
    my $total_diskiodevice = 0;
    foreach my $key ($self->{snmp}->oid_lex_sort(keys %$result)) {
        next if ($key !~ /\.([0-9]+)$/);
        $self->{datas}->{'diskIODevice_' . $1} = $self->{output}->decode($result->{$key});
        $total_diskiodevice = $1;
    }
    
    if (scalar(keys %{$self->{datas}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "Can't get disks IO device...");
        $self->{output}->option_exit();
    }
    
    if (!defined($self->{option_results}->{use_name}) && defined($self->{option_results}->{diskiodevice})) {
        # get by ID
        push @{$self->{diskiodevice_id_selected}}, $self->{option_results}->{diskiodevice}; 
        my $name = $self->{datas}->{'diskIODevice_' . $self->{option_results}->{diskiodevice}};
        if (!defined($name)) {
            $self->{output}->add_option_msg(short_msg => "No disk IO device found for id '" . $self->{option_results}->{diskiodevice} . "'.");
            $self->{output}->option_exit();
        }
    } else {
        for (my $i = 0; $i <= $total_diskiodevice; $i++) {
            my $filter_name = $self->{datas}->{'diskIODevice_' . $i};
            next if (!defined($filter_name));
            if (!defined($self->{option_results}->{diskiodevice})) {
                push @{$self->{diskiodevice_id_selected}}, $i; 
                next;
            }
            if (defined($self->{option_results}->{use_regexp}) && defined($self->{option_results}->{use_regexpi}) && $filter_name =~ /$self->{option_results}->{diskiodevice}/i) {
                push @{$self->{diskiodevice_id_selected}}, $i; 
            }
            if (defined($self->{option_results}->{use_regexp}) && !defined($self->{option_results}->{use_regexpi}) && $filter_name =~ /$self->{option_results}->{diskiodevice}/) {
                push @{$self->{diskiodevice_id_selected}}, $i; 
            }
            if (!defined($self->{option_results}->{use_regexp}) && !defined($self->{option_results}->{use_regexpi}) && $filter_name eq $self->{option_results}->{diskiodevice}) {
                push @{$self->{diskiodevice_id_selected}}, $i; 
            }
        }
        
        if (scalar(@{$self->{diskiodevice_id_selected}}) <= 0 && !defined($options{disco})) {
            if (defined($self->{option_results}->{diskiodevice})) {
                $self->{output}->add_option_msg(short_msg => "No disk IO device found for name '" . $self->{option_results}->{diskiodevice} . "'.");
            } else {
                $self->{output}->add_option_msg(short_msg => "No disk IO device found.");
            }
            $self->{output}->option_exit();
        }
    }
}

sub disco_format {
    my ($self, %options) = @_;
    
    $self->{output}->add_disco_format(elements => ['name', 'diskiodeviceid']);
}

sub disco_show {
    my ($self, %options) = @_;
    $self->{snmp} = $options{snmp};

    $self->manage_selection(disco => 1);
    return if (scalar(@{$self->{diskiodevice_id_selected}}) == 0);
    my $result = $self->get_additional_information();
    foreach (sort @{$self->{diskiodevice_id_selected}}) {
        my $display_value = $self->get_display_value(id => $_);

        $self->{output}->add_disco_entry(name => $display_value,
                                         diskiodeviceid => $_);
    }
}

1;

__END__

=head1 MODE

List disk IO device (UCD-DISKIO-MIB).
Need to enable "includeAllDisks 10%" on snmpd.conf.

=over 8

=item B<--diskiodevice>

Set the disk IO device (number expected) ex: 1, 2,... (empty means 'check all disks IO device').

=item B<--name>

Allows to use disk IO device name with option --diskiodevice instead of disk IO device oid index.

=item B<--regexp>

Allows to use regexp to filter diskiodevice (with option --name).

=item B<--regexp-isensitive>

Allows to use regexp non case-sensitive (with --regexp).

=item B<--display-transform-src>

Regexp src to transform display value. (security risk!!!)

=item B<--display-transform-dst>

Regexp dst to transform display value. (security risk!!!)

=item B<--skip-total-size-zero>

Filter partitions with total size equals 0.

=back

=cut
