package Chunzi::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Path::Class;
use File::Slurp;
use Class::Date qw(date now);
use DateTime;
use XML::Feed;
use Chunzi::Post;
use File::Copy;

__PACKAGE__->config->{namespace} = '';

sub auto : Private {
    my ( $self, $c ) = @_;
    $c->stash->{'template_layout'} = [ 'layout.html' ];
	1;
}

sub collect_posts : Private {
	my ( $self, $c ) = @_;

	my @posts = Chunzi::Post->read_posts( $c->config->{'post_dir'} );
	$c->stash->{'posts'} = \@posts;

	my $bydate;
	map {
		my $mb = $_->{'date'}->month_begin;
		push @{$bydate->{$mb->year}{$mb->month}}, $_;
	} @posts;

	my @bydate;
	foreach my $year ( sort { $b <=> $a } keys %$bydate ){
		foreach my $month ( sort { $b <=> $a } keys %{$bydate->{$year}} ){
			push @bydate, { year => $year, month => $month, posts => $bydate->{$year}{$month} }
		}
	}

	$c->stash->{'posts_bydate'} = \@bydate;
}

sub default : Private {
	my ( $self, $c ) = @_;
	$c->forward('page');
}

sub page : Local {
	my ( $self, $c, $page ) = @_;

	$c->forward('collect_posts');

	my $posts = $c->stash->{'posts'};
	my $posts_count = $#{$posts};
	my $num_per_page = $c->config->{'num_per_page'};
	my $last_page = int( $posts_count / $num_per_page + 1 );

	$page ||= 1;
	$page = $last_page if $page > $last_page;
	
	my $first = ( $page - 1 ) * $num_per_page;
	my $last = $page * $num_per_page - 1;

    $c->stash->{'page'} = $page;
    $c->stash->{'last_page'} = $last_page;
    $c->stash->{'paged_posts'} = [ @$posts[$first..$last] ];
    $c->stash->{'template'} = 'page.html';
}

sub posts : Local {
	my ( $self, $c, $page ) = @_;
	$c->forward('collect_posts');
    $c->stash->{'template'} = 'posts.html';
}

sub post : Local {
	my ( $self, $c, $uid ) = @_;

	$c->forward('collect_posts');
	my $posts = $c->stash->{'posts'};
	foreach my $idx ( 0 .. $#{$posts} ){
		if ( $posts->[$idx]->{'uid'} eq $uid ){
			$c->stash->{'post'} = $posts->[$idx];
			$c->stash->{'post_prev'} = $posts->[$idx-1] if $idx > 1;
			$c->stash->{'post_next'} = $posts->[$idx+1] if $idx < $#{$posts};
			last;
		}
	}
    $c->stash->{'template'} = 'post.html';
}

sub atom : Path('atom.xml') {
	my ( $self, $c ) = @_;

	$c->forward('collect_posts');

	my $feed = XML::Feed->new('Atom');
	$feed->title( "三下五除二" );
	$feed->link( $c->req->base );
	$feed->description("Chunzi's blog"); 

	foreach ( 0 .. 11 ) {
		my $post = $c->stash->{'posts'}->[$_];
		my $feed_entry = XML::Feed::Entry->new('Atom');
		$feed_entry->title( $post->{'title'} );
		$feed_entry->content( $post->{'content'} );
		$feed_entry->link( $c->uri_for( "/post/". $post->{'uid'} ) );
		$feed_entry->issued( DateTime->from_epoch( epoch => $post->{'date'}->epoch ) );
		$feed->add_entry( $feed_entry );
	}

	$c->res->content_type('application/atom+xml');
	$c->res->body( $feed->as_xml );
}

sub write : Local {
	my ( $self, $c, $uid ) = @_;
	
	# prepare the draft saving
	my $dir = dir( $c->config->{'post_dir'} );
	my $draft_dir = $dir->subdir('drafts');
	-d $draft_dir or $draft_dir->mkpath(0, 0777);

	# start edit a post
	if ( $uid ){
		my $index = Chunzi::Post->read_posts_index( $c->config->{'post_dir'} );
		my $post = Chunzi::Post->get_post_by_uid( $index, $uid );

		# copy to draft
		my $publish_file = $post->path;
		my $draft_file = $draft_dir->file( $post->uid );
		copy( "$publish_file", "$draft_file" );

		$c->stash->{'format'} = $post->format;
		$c->stash->{'content'} = $post->filetext;

	# new post
	}else{
		$uid = now()->epoch;
	}

    $c->stash->{'uid'} = $uid;
	
	if( $c->req->param('publish') ){

		# get the post
		my $post = Chunzi::Post->new_from_text( $c->req->param('content') );
		$post->uid( $c->req->param('uid') );
		$post->format( $c->req->param('format') );
	
	
		# save as latest draft
		my $saving_file = $draft_dir->file( $post->uid );
		write_file( "$saving_file", $post->filetext );
		
		my $publish_file = $dir->file( $post->publish_filename );
		move( "$saving_file", "$publish_file" );

		$c->res->redirect( $c->uri_for("/post/".$post->uid) );
	}

    $c->stash->{'template_layout'} = [];
    $c->stash->{'template'} = 'write.html';
}

sub preview : Local {
	my ( $self, $c ) = @_;
	
	# get the post
	my $post = Chunzi::Post->new_from_text( $c->req->param('content') );
	$post->uid( $c->req->param('uid') );
	$post->format( $c->req->param('format') );

	# prepare the draft saving
	my $dir = dir( $c->config->{'post_dir'} );
	my $draft_dir = $dir->subdir('drafts');
	-d $draft_dir or $draft_dir->mkpath(0, 0777);
	
	# save this draft
	my $saving_file = $draft_dir->file( $post->uid );
	write_file( "$saving_file", $post->filetext );

	# show me
    $c->stash->{'post'} = $post;
    $c->stash->{'template_layout'} = [];
    $c->stash->{'template'} = 'preview.html';
}

=head1 NAME

Chunzi::Controller::Root - Root Controller for Chunzi

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Chunzi Sheng,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
