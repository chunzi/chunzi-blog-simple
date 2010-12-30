package Chunzi::View::TT;

use strict;
use base 'Catalyst::View::TT::Layout';

Chunzi::View::TT->config({
	COMPILE_DIR  => ('/tmp' ),
    INCLUDE_PATH => [
        Chunzi->path_to( 'root', 'templates' ),
    ],
});

=head1 NAME

Chunzi::View::TT - Layout TT View Component

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice component.

=head1 AUTHOR

Chunzi Sheng,,,

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it 
under the same terms as perl itself.

=cut

1;
