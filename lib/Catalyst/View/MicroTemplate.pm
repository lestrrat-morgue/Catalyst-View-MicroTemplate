package Catalyst::View::MicroTemplate;
use Moose;
use MooseX::AttributeHelpers;
use Text::MicroTemplate;

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

has include_paths => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[Path::Class::Dir]',
    required => 1,
    provides => {
        elements => 'all_include_paths',
    }
);

has template_args => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1
);

sub BUILDARGS {
    my ($self, $c, $args) = @_;

    $args->{namespace} ||= $c;
    $args->{include_paths} ||= [];
    my $paths = $args->{include_paths};
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

sub build_template {
    my ($self, $file) = @_;

    my $mt;
    {
        my $ref = ref $file;
        my %args;
        if ($ref && $ref eq 'SCALAR') {
            $args{package_name}  = ref($self) . '::' . Digest::MD5::md5_hex( $$file );
            $args{template} = $$file;
        } else {
            # I don't think this is cross-platform...
            my @name =
                grep { defined && length } 
                map { s/[^\w:]/::/g; $_ }
                File::Spec->splitpath( $file )
            ;
            $args{package_name} = join('::', ref($self), @name );
            my $loaded = 0;
            foreach my $path ($self->all_include_paths) {
                eval {
                    my $content = $path->file( $file )->slurp;
                    $args{template} = $content;
                    $loaded++;
                };
                last if $loaded;
            }
            if (! $loaded) {
                die "Could not find template file named $file";
            }
        }
        $mt = Text::MicroTemplate->new(%{$self->template_args}, %args);
    }
    my $code = $mt->code;
    my $builder = eval <<"    ...";
        sub {
            my (\$c, \$args) = \@_;
            $code->();
        }
    ...
    die if $@;
    return $builder;
}

sub render {
    my ($self, $template, $args) = @_;
    my $builder = $self->build_template( $template );
    return $builder->($self->context, $args);
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

Values passed to the stash are available to the template like Catalyst::View::TT, but they must be accessed through C<$args> hash reference.

=cut