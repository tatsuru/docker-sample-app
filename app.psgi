use strict;
use warnings;

use Plack::Builder;
use Plack::Middleware::AxsLog;
use Path::Class;

my $app = sub {
    my $env = shift;
    return [
        200,
        [ 'Content-Type' => 'text/plain' ],
        [ "Hello, World" ],
    ];
};

builder {
    my $access_log = Path::Class::file($ENV{ACCESS_LOG} || "/var/log/app/access_log");
    my $error_log  = Path::Class::file($ENV{ERROR_LOG}  || "/var/log/app/error_log");

    my $fh_access = $access_log->open('>>')
        or die "Cannot open >> $access_log: $!";
    my $fh_error  = $error_log->open('>>')
        or die "Cannot open >> $error_log: $!";

    $_->autoflush(1) for $fh_access, $fh_error;

    enable 'Plack::Middleware::AxsLog',
            ltsv          => 1,
            response_time => 1,
            logger        => sub { print $fh_access @_ };
    $app;
};
