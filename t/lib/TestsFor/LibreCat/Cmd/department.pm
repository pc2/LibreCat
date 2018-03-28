package TestsFor::LibreCat::Cmd::department;
use Test::Class::Moose extends => 'TestsFor::LibreCat::Cmd';

sub test_tree {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'tree', 't/records/valid-department-tree.yml']);

    ok !$result->error, "threw no exception";

    like $result->output, qr/deleting previous departments/,
        "clean tree before adding";

    $result = test_app(qq|LibreCat::CLI| => ['department', 'tree',]);

    ok !$result->error, "threw no exception";
    like $result->output, qr/tree:/, "tree ouput";
}

1;
