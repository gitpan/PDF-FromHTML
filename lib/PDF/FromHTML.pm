package PDF::FromHTML;
$PDF::FromHTML::VERSION = '0.04';

use strict;
use warnings;
use Spiffy '-base';

field 'pdf';
field 'twig';
field 'args';

use Cwd;
use XML::Clean;
use File::Temp;
use File::Basename;
use Hook::LexWrap;

use PDF::Writer 'pdfapi2';
use PDF::Template;
use PDF::FromHTML::Twig;

=head1 NAME

PDF::FromHTML - Convert HTML documents to PDF

=head1 VERSION

This document describes version 0.04 of PDF::FromHTML, released 
September 23, 2004.

=head1 SYNOPSIS

    my $pdf = PDF::FromHTML->new( encoding => 'utf-8' );
    $pdf->load_file('source.html');
    $pdf->convert(
        Font => '/path/to/font.ttf',
        LineHeight => 10,
        Landscape => 1,
    );
    $pdf->write_file('target.pdf');

=head1 DESCRIPTION

This module transforms HTML into PDF, using an assortment of XML
transformations implemented in L<PDF::FromHTML::Twig>.

There is also a command-line utility, L<html2pdf.pl>, that comes
with this distribution.

More documentation is expected soon.

=cut

sub new {
    my $class = shift;
    bless({
        twig => PDF::FromHTML::Twig->new,
        args => { @_ },
    }, $class);
}

sub load_file {
    my ($self, $file) = @_;
    $self->{file} = $file;
}

sub parse_file {
    my $self = shift;
    my $file = $self->{file};

    my $dir = Cwd::getcwd();
    if (!ref $file) {
        open my $fh, $file or die $!;
        chdir File::Basename::dirname($file);
        $file = \do { local $/; <$fh> };
    }
    else {
        $file = \"$$file";
    }
    $$file =~ s{<!--\s.*?\s-->}{}gs;

    # lower-case all tags
    my $lc_tags = Hook::LexWrap::wrap(
        *XML::Clean::handle_start,
        pre => sub {
            $_[0] = lc($_[0]);
            $_[0] = 'i' if $_[0] eq 'em';
            $_[0] = 'b' if $_[0] eq 'strong';
        },
    );

    my $cleaned = XML::Clean::clean($$file, '1.0', $self->args);
    $self->twig->parse($cleaned);
    chdir $dir;
}

sub convert {
    my ($self, %args) = @_;

    {
        # import arguments into Twig parameters
        no strict 'refs';
        ${"PDF::FromHTML::Twig::$_"} = $args{$_} foreach keys %args;
    }

    $self->parse_file;

    my ($fh, $filename) = File::Temp::tempfile(
        SUFFIX => '.xml',
        UNLINK => 1,
    );
    binmode($fh);
    print $fh $self->twig->sprint;
    close $fh;

    $self->pdf(eval { PDF::Template->new( filename => $filename ) })
      or die "$filename: $@";
    $self->pdf->param(@_);
}

sub write_file {
    my $self = shift;
    $self->pdf->write_file(@_);
}

1;

=head1 SEE ALSO

L<PDF::FromHTML::Twig>, L<PDF::Template>, L<XML::Twig>.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
