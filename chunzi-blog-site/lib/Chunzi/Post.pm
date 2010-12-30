package Chunzi::Post;

use strict;
use warnings;

use Path::Class;
use File::Slurp;
use Class::Date qw(now);
use Text::Textile 'textile';
use Text::Markdown 'markdown';

use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors($_) for qw/
	path
	uid format status
	date
	title content
/;

sub read_posts {
	my $class = shift;
	my $dir = dir shift;

	my $index = $class->read_posts_index( $dir );

	my @posts;
	map {
		push @posts, $class->get_post_by_uid( $index, $_ );
	} reverse sort keys %$index;

	return @posts;
}

sub read_posts_index {
	my $class = shift;
	my $dir = dir shift;
	return unless -d $dir;

	# only non-temp files
	my @post_files = grep { "$_" !~ /~$/ } grep { -f $_ } $dir->children;

	my $index;
	map {
		my ( $uid, $format, $status ) = split( /\./, $_->basename );
		$index->{$uid} = {
			'format' => $format,
			'status' => $status,
			'path' => $_
		};
	} @post_files;
	return $index;
}

sub get_post_by_uid {
	my $class = shift;
	my $index = shift;
	my $uid = shift;
	return $class->new_from_file( $index->{$uid}{'path'}->stringify );
}

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	return $self;
}

sub new_from_file {
	my $class = shift;
	my $path = file shift;
	return unless -f $path;

	my ( $uid, $format, $status ) = split( /\./, $path->basename );

	my $post = $class->new_from_text( scalar read_file("$path") );
	$post->path( $path );
	$post->uid( $uid );
	$post->format( $format );
	$post->status( $status );
	$post->date( Class::Date::date( $uid ) );
	
	return $post;
}

sub new_from_text {
	my $class = shift;
	my $text = shift;
	return unless defined $text;

	my @lines = split(/\n/, $text);
	my $title = shift @lines;

	my $content = join("\n", @lines);
	$content =~ s/^\n+|\n$//g;

	my $post = new Chunzi::Post;
	$post->title( $title );
	$post->content( $content );
	return $post;
}


sub rendered {
	my $self = shift;
	my $text = $self->content;


	if ( $self->format eq 'textile' ){
		return textile($text);

	}elsif ( $self->format eq 'markdown' ){
		return markdown($text);
		

	}
	return $text;
}

sub filetext {
	my $self = shift;
	return join("\n\n", $self->title, $self->content);
}

sub publish_filename {
	my $self = shift;
	return join('.',
		$self->uid || now()->epoch,
		$self->format || 'text'
	);
}

1;


