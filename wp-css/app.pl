use strict;
use warnings;
use utf8;

use Data::Dumper;

use CSS::Simple;
use CSS::Tidy qw/tidy_css/;
use Data::Walk;
use File::Find;
use File::Slurp;
use JSON;
use Scalar::Util qw/reftype/;

# Read in the contents of the theme's JSON file.

my $json = from_json( read_file( '/theme/theme.json', binmode => 'utf8' ) );

# Remove any existing css properties from the JSON.

sub remove_css
{
    if (
        $_ eq 'css' &&
        $Data::Walk::index % 2 == 0 &&
        ref $Data::Walk::container &&
        reftype $Data::Walk::container eq reftype {}
    ) {
        # This node is a hash key whose name is 'css', so delete it.
        delete $Data::Walk::container->{css};
    }
}

walk \&remove_css, $json;

# Remove any properties from the JSON that now reference only an empty hash.

my $work_to_do = 1; # Each pass that deletes a key may create new, empty hashes.

sub remove_empty
{
    if (
        $Data::Walk::index % 2 == 1 &&
        ref $_ &&
        reftype $_ eq reftype {} &&
        ! scalar %$_
    ) {
        # This node is an empty hash value, remove the key that references it.
        foreach my $key ( keys %$Data::Walk::container ) {
            # Loops through every key in the parent hash.
            if (
                ref $Data::Walk::container->{$key} &&
                reftype $Data::Walk::container->{$key} eq reftype {} &&
                ! scalar %{$Data::Walk::container->{$key}}
            ) {
                # This is the key in the parent hash referencing an empty hash.
                delete $Data::Walk::container->{$key};
                $work_to_do = 1;
            }
        }
    }
}

while ( $work_to_do ) {

    $work_to_do = 0; # Assume no change on this pass until proved otherwise.
    walk \&remove_empty, $json;

}

# Add global (not block specific) custom CSS into the theme.json if defined.

if ( -f '/theme/css/global.css' ) {

    my %options = ( decomment => 1 );
    my $css = tidy_css (
        read_file( '/theme/css/global.css' ), %options
    );
    $json->{styles}->{css} = $css;

}

# Add any block specific custom CSS into the theme.json if defined.

sub wanted
{
    if ( $File::Find::name =~ m~^/theme/css/blocks/([\w-]+/[\w-]+)\.css$~ ) {
        my $cssObj = new CSS::Simple();
        $cssObj->read_file( { filename => "$File::Find::name" } );
        my %options = ( decomment => 1 );
        my $css = tidy_css(
            $cssObj->output_selector( { selector => 'block-style' } ), %options
        );
        $json->{styles}->{blocks}->{$1}->{css} = $css;
    }
}

find( \&wanted, ( '/theme/css/blocks/' ) );

# Write out the revised (possibly) theme.json file.

open( FH, '>', '/theme/theme.json' );
print FH JSON->new->canonical->pretty->encode( $json );
close( FH );

1;
