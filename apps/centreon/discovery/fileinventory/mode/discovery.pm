#
# Copyright 2022 Centreon (http://www.centreon.com/)
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

package apps::centreon::discovery::fileinventory::mode::discovery;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use JSON::XS;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'prettify'      => { name => 'prettify' },
        'input-file:s'  => { name => 'input_file'},
        'line-format:s' => { name => 'line_format' },
        'delimiter:s'   => { name => 'delimiter' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{input_file}) || $self->{option_results}->{input_file} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify the --input-file option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{line_format}) || $self->{option_results}->{line_format} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify the --line-format option.");
        $self->{output}->option_exit();
    }

    $self->{input_file} = defined($self->{option_results}->{input_file})  && $self->{option_results}->{input_file} ne '' ? $self->{option_results}->{input_file} : '';
    $self->{line_format} = defined($self->{option_results}->{line_format})  && $self->{option_results}->{line_format} ne '' ? $self->{option_results}->{line_format} : '';
    $self->{delimiter} = defined($self->{option_results}->{delimiter})  && $self->{option_results}->{delimiter} ne '' ? $self->{option_results}->{delimiter} : ';';
}

sub parse_file {
    my ($self, %options) = @_;
    my $results = [];

    open(my $fh, '<', $self->{input_file}) or die "Can't read file '$self->{input_file}' [$!]\n";

    $self->{input_file} =~ /([^.]+)$/;

    if (lc($1) eq 'csv' ) {
        while (my $line = <$fh>) {
            my $data;
            chomp $line;
            my @fields = split(/$self->{delimiter}/, $line);
            if (scalar(@fields) != $options{entries}) {
                $self->{output}->add_option_msg(
                    short_msg => sprintf('Number of fields are not matching, found: %d, defined: %d', scalar(@fields), $options{entries})
                );
                $self->{output}->option_exit();
            }
            for (my $i = 0; $i < scalar(@fields); $i++) {
                $data->{ $options{mapping}->{$i} } = $fields[$i];
            }
            push @$results, $data;
        }
    }
    close $fh;

    return $results;
}

sub run {
    my ($self, %options) = @_;

    my $disco_stats;
    $disco_stats->{start_time} = time();


    my @attributes = split(/$self->{delimiter}/, $self->{line_format});
    my $index;
    for (my $i = 0; $i < scalar(@attributes); $i++) {
        $index->{$i} = $attributes[$i];
    }

    my $results = $self->parse_file(mapping => $index, entries => scalar(@attributes));

    $disco_stats->{end_time} = time();
    $disco_stats->{duration} = $disco_stats->{end_time} - $disco_stats->{start_time};
    $disco_stats->{discovered_items} = scalar(@$results);
    $disco_stats->{results} = $results;

    my $encoded_data;
    eval {
        if (defined($self->{option_results}->{prettify})) {
            $encoded_data = JSON::XS->new->utf8->pretty->encode($disco_stats);
        } else {
            $encoded_data = JSON::XS->new->utf8->encode($disco_stats);
        }
    };
    if ($@) {
        $encoded_data = '{"code":"encode_error","message":"Cannot encode discovered data into JSON format"}';
    }

    $self->{output}->output_add(short_msg => $encoded_data);
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1);
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Centreon CSV File Inventory discovery.

=over 8

=item B<--prettify>

Prettify JSON output.

=item B<--input-file>

*MANDATORY*
Specify the path of the Inventory file.
Example: "--input-file='/tmp/my_inventory_file.csv"

=item B<--line-format>

*MANDATORY*
Specify the format of the the fields in file.
Example: "--line-format='name;ip;alias;devicetype;geo_coords"

=item B<--delimiter>

Define the fields delimiter (Default: ';').

=back

=cut
