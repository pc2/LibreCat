package LibreCat;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use LibreCat::Hook;
use LibreCat::Search;
use Catmandu;
use namespace::clean;

sub searcher {
    state $searcher = do {
        LibreCat::Search->new(store => Catmandu->store('search'));
    }
}

{
    my $hook_ns = 'LibreCat::Hook';
    my $hooks = {};

    sub hook {
        my ($self, $name) = @_;
        $hooks->{$name} ||= do {
            my $args = {
                before_fixes => [],
                after_fixes  => [],
            };

            my $hook = (Catmandu->config->{hooks} || {})->{$name} || {};
            for my $key (qw(before_fixes after_fixes)) {
                my $fixes = $hook->{$key} || [];
                for my $fix (@$fixes) {
                    push @{$args->{$key}}, require_package($fix, $hook_ns)->new;
                }
            }

            LibreCat::Hook->new($args);
        };
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat - Librecat helper functions

=head1 SYNOPSIS

   use LibreCat;

   # Given a 'catmandu' configuration file, like: catmandu.hooks.yml
   # --
   # hooks:
   #   myhook:
   #      before_fixes: [BeforeFix1,BeforeFix2]
   #      after_fixes:  [AfterFix]

   my $hook = LibreCat->hook('eat');

   $hook->fix_before($data);  # BeforeFix1->fix($data) and
                              # BeforeFix2->fix($data) will be executed
   $hook->fix_after($data);   # AfterFix->fix($data) will be executed

=cut
