package Catalyst::View::MicroTemplate;
use Moose;
use Text::MicroTemplate::File;

our $VERSION = '0.00001';

extends 'Catalyst::View';

has namespace => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has context => (
    is => 'rw',
    isa => 'Catalyst',
);

has content_type => (
    is => 'ro',
    isa => 'Str',
    default => 'text/html'
);

has charset => (
    is => 'ro',
    isa => 'Str',
    default => 'utf8',
);

has suffix => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1
);

has stash_key => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1
);

has template_args => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1
);

has template => (
    is => 'ro',
    isa => 'Text::MicroTemplate::File',
    lazy_build => 1,
);

sub BUILDARGS {
    my ($self, $c, $args) = @_;

    $args->{namespace} ||= $c;
    $args->{template_args} ||= {};
    $args->{template_args}->{include_path} ||= [];
    my $paths = $args->{template_args}->{include_path};
    if (scalar @$paths < 1) {
        push @$paths, $c->path_to('root');
    }
    return $self->next::method($args);
}

sub ACCEPT_CONTEXT {
    my ($self, $c) = @_;
    $self->context($c);
    return $self;
}

sub _build_suffix {
    return '';
}

sub _build_stash_key {
    my $self = shift;
    return '__' . ref($self) . '_template';
}

sub _build_template_args {
    return {};
}

sub _build_template {
    my ($self) = @_;

    return Text::MicroTemplate::File->new(
        $self->template_args
    );
}

sub render {
    my ($self, $template, $args) = @_;
    my $mt = $self->template;
    return $mt->render_file($template, $self->context, $args);
}

sub process {
    my ($self) = @_;

    my $c = $self->context;
    my $template = $self->get_template_file( $c );
    $c->log->debug( sprintf("[%s] rendering template %s", blessed $self, $template ) ) if $c->debug;

    $c->res->content_type( sprintf("%s; charset=%s", $self->content_type, $self->charset ) );
    $c->res->body( $self->render( $template, $c->stash ) );
}

sub get_template_file {
    my ($self, $c) = @_;
    
    # hopefully they're using the new $c->view->template
    my $template = $c->stash->{$self->stash_key()};
    
    # if that's empty, get the template the old way, $c->stash->{template}
    $template ||= $c->stash->{template};
    
    # if those aren't set, try $c->action and the suffix
    $template ||= $c->action . ($self->suffix);
    
    return $template;
}

1;

__END__

=head1 NAME

Catalyst::View::MicroTemplate - Text::MicroTemplate View For Catalyst

=head1 SYNOPSIS

    package MyApp::View::MicroTemplate;
    use strict;
    use base qw(Catalyst::View::MicroTemplate);

=head1 DESCRIPTION

This is a Text::MicroTemplate view for Catalyst.

=head1 CAVEATS

Values passed to the stash are available to the template like Catalyst::View::TT, but they must be received by normal means. i.e.

    <? my ($c, $args) = @_ ?>
    # $args contains contents of stash

=cut