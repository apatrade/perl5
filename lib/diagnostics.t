#!./perl -w

BEGIN {
    chdir '..' if -d '../pod' && -d '../t';
    @INC = 'lib';
    require './t/test.pl';
    plan(15);
}

BEGIN {
    my $w;
    $SIG{__WARN__} = sub { $w = shift };
    use_ok('diagnostics');
    is $w, undef, 'no warnings when loading diagnostics.pm';
}

require base;

eval {
    'base'->import(qw(I::do::not::exist));
};

like( $@, qr/^Base class package "I::do::not::exist" is empty/);

open *whatever, ">", \my $warning
    or die "Couldn't redirect STDERR to var: $!";
my $old_stderr = *STDERR{IO};
*STDERR = *whatever{IO};

# Test for %.0f patterns in perldiag, added in 5.11.0
warn('gmtime(nan) too large');
like $warning, qr/\(W overflow\) You called/, '%0.f patterns';

# L<foo/bar> links
seek STDERR, 0,0;
$warning = '';
warn("accept() on closed socket spanner");
like $warning, qr/"accept" in perlfunc/, 'L<foo/bar> links';

# L<foo|bar/baz> links
seek STDERR, 0,0;
$warning = '';
warn
 'Lexing code attempted to stuff non-Latin-1 character into Latin-1 input';
like $warning, qr/using lex_stuff_pvn or similar/, 'L<foo|bar/baz>';

# Multiple messages with the same description
seek STDERR, 0,0;
$warning = '';
warn 'Code point 0xBEE5 is not Unicode, may not be portable';
like $warning, qr/W utf8/,
   'Message sharing its description with the following message';

# Periods at end of entries in perldiag.pod get matched correctly
seek STDERR, 0,0;
$warning = '';
warn "Execution of -e aborted due to compilation errors.\n";
like $warning, qr/The final summary message/, 'Periods at end of line';

# Test for %d/%u
seek STDERR, 0,0;
$warning = '';
warn "Bad arg length for us, is 4, should be 42";
like $warning, qr/In C parlance/, '%u works';

# Test for %X
seek STDERR, 0,0;
$warning = '';
warn "Unicode surrogate U+C0FFEE is illegal in UTF-8";
like $warning, qr/You had a UTF-16 surrogate/, '%X';

# Strip S<>
seek STDERR, 0,0;
$warning = '';
warn "syntax error";
like $warning, qr/cybernetic version of 20 questions/s, 'strip S<>';

*STDERR = $old_stderr;

# These tests use a panic under the hope that the description is not likely
# to change.
@runperl_args = (
        switches => [ '-Ilib', '-Mdiagnostics' ],
        stderr => 1,
        nolib => 1, # -I../lib would go outside the build dir
);
$subs =
 "sub foo{bar()}sub bar{baz()}sub baz{die q _panic: gremlins_}foo()";
is runperl(@runperl_args, prog => $subs),
   << 'EOT', 'internal error with backtrace';
panic: gremlins at -e line 1 (#1)
    (P) An internal error.
    
Uncaught exception from user code:
	panic: gremlins at -e line 1.
	main::baz() called at -e line 1
	main::bar() called at -e line 1
	main::foo() called at -e line 1
EOT
is runperl(@runperl_args, prog => $subs =~ s/panic\K/k/r),
   << 'EOU', 'user error with backtrace';
Uncaught exception from user code:
	panick: gremlins at -e line 1.
	main::baz() called at -e line 1
	main::bar() called at -e line 1
	main::foo() called at -e line 1
EOU
is runperl(@runperl_args, prog => 'die q _panic: gremlins_'),
   << 'EOV', 'no backtrace from top-level internal error';
panic: gremlins at -e line 1 (#1)
    (P) An internal error.
    
Uncaught exception from user code:
	panic: gremlins at -e line 1.
EOV
is runperl(@runperl_args, prog => 'die q _panick: gremlins_'),
   << 'EOW', 'no backtrace from top-level user error';
Uncaught exception from user code:
	panick: gremlins at -e line 1.
EOW
