package Plack::Debugger::Panel::NYTProf;

# ABSTRACT: Plack::Debugger::Panel for NYTProf
use strict;
use warnings;

use parent 'Plack::Debugger::Panel';

sub new {
    my $class = shift;
    my %args = @_ == 1 && ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    $args{title}     ||= 'NYTProf';
    $args{formatter} ||= 'pass_through';
    $args{root}      ||= '/tmp/nytprof';

    mkdir $args{root} unless -e $args{root};

    my $file = $args{root} . qq{/nytprof.out};
    $ENV{NYTPROF} = "addpid=1:file=$file";
    require Devel::NYTProf;

    $args{before} = sub {

        # DB::enable_profile($file);
    };

    $args{after} = sub {
        my ( $self, $env ) = @_;

        # skip ajax requests for now
        return
            if defined $env->{HTTP_X_REQUESTED_WITH}
            && $env->{HTTP_X_REQUESTED_WITH} eq 'XMLHttpRequest';

        DB::disable_profile();
        DB::finish_profile();

        if ( -f qq{$file.$$} ) {
            my $out_dir = $args{root} . qq{/$$};
            system qq{nytprofhtml -f $file.$$ -o $out_dir};

            my $result = <<"EOF";
            <a href="/nytprof/$$/index.html" target="_blank">(open in a new window)</a><br>
            <iframe src ="/nytprof/$$/index.html" width="100%" height="100%">
                <p>Your browser does not support iframes.</p>
            </iframe>
EOF
            $self->set_result($result);
        }
    };

    $class->SUPER::new( \%args );
}

1;

__END__

=head1 DESCRIPTION

Run Devel::NYTProf in Plack::Debugger.

=head1 SYNOPSIS

    use Plack::Builder;

    use JSON;

    use Plack::Debugger;
    use Plack::Debugger::Storage;

    use Plack::App::Debugger;

    use Plack::Debugger::Panel::Timer;
    use Plack::Debugger::Panel::AJAX;
    use Plack::Debugger::Panel::Memory;
    use Plack::Debugger::Panel::Warnings;

    my $debugger = Plack::Debugger->new(
        storage => Plack::Debugger::Storage->new(
            data_dir     => '/tmp/debugger_panel',
            serializer   => sub { encode_json( shift ) },
            deserializer => sub { decode_json( shift ) },
            filename_fmt => "%s.json",
        ),
        panels => [
            Plack::Debugger::Panel::NYTProf->new( root => '/tmp/nytprof' )   
        ]
    );

    my $debugger_app = Plack::App::Debugger->new( debugger => $debugger );

    builder {
        mount $debugger_app->base_url => $debugger_app->to_app;

        mount '/nytprof' => Plack::App::File->new( root => '/tmp/nytprof' )->to_app;

        mount '/' => builder {
            enable $debugger_app->make_injector_middleware;
            enable $debugger->make_collector_middleware;
            $app;
        }
    };

=head1 DESCRIPTION

This is a very initial stab at a NYTProf panel for L<Plack::Debugger>. You probably do not want to use it yet.

=head1 SEE ALSO

L<Plack::Debugger>

L<Devel::NYTProf>

L<Plack::Middleware::Debug::Profiler::NYTProf>
 

