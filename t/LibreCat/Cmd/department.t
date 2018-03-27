use strict;
use warnings FATAL => 'all';
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Catmandu;
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::department';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('main')->bag('department')->delete_all;
Catmandu->store('search')->bag('department')->delete_all;
Catmandu->store('main')->bag('department_version')->delete_all;

subtest 'initial cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department']);
    ok $result->error, 'missing command: threw an exception';

    $result = test_app(qq|LibreCat::CLI| => ['department', 'nonsense-command']);
    ok $result->error, 'non-valid command: threw an exception';
    like $result->error, qr/Error.*?should be one of/, 'print valid commands';
};

subtest 'help' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', '-h']);
    ok $result->error, 'help cmd: throw an exception';
    like $result->stdout, qr/print this usage screen/, 'print help';
};

subtest 'empty list' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'list']);

    ok !$result->error, 'list: threw no exception';

    my $output = $result->stdout;
    ok $output , 'list departments: got an output';

    my $count = count_department($output);

    ok $count == 0, 'count for list departments';
};

subtest 'validate' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'valid', 't/records/invalid-department.yml']);

    ok $result->error, "file not valid";
    like $result->output, qr/^ERROR/, "output for not valid file";

    $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'valid', 't/records/valid-department.yml']);
    ok !$result->error, "file valid";
    unlike $result->output, qr/^ERROR/, "output for valid file";
};

subtest 'add invalid' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add']);
    ok $result->error, 'missing file in add';

    like $result->error, qr/usage.*add/, "need file";

    $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add', 't/records/fjlasdjflsa.yml']);

    ok $result->error, 'nonexistent file in add';

    like $result->error, qr/usage.*add/, "need file";

    $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add', 't/records/invalid-department.yml']);
    ok $result->error, 'add invalid department: threw an exception';
};

subtest 'add valid' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add', 't/records/valid-department.yml']);

    ok !$result->error, 'add valid department: threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added 999000999/, 'added 999000999';

    my $stored_record
        = Catmandu->store('main')->bag('department')->get('999000999');
    is $stored_record->{_id}, '999000999', 'stored record id';

    my $indexed_record
        = Catmandu->store('search')->bag('department')->get('999000999');
    is $indexed_record->{_id}, '999000999', 'indexed record id';
};

subtest 'get' => sub {
    my $result
        = test_app(qq|LibreCat::CLI| => ['department', 'get', '999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id},  999000999,      'got really a 999000999 record';
    is $record->{name}, 'Test faculty', 'got a valid department';

    $result = test_app(qq|LibreCat::CLI| => ['department', 'get', 't/records/department-ids.txt']);

    ok !$result->error, 'ok threw no exception';

    $output = $result->stdout;

    ok $output , 'got an output';
};

subtest 'list' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'list']);

    ok !$result->error, 'list: threw no exception';

    my $output = $result->stdout;
    ok $output , 'list departments: got an output';

    my $count = count_department($output);

    ok $count == 1, 'count for list departments';


    $result = test_app(qq|LibreCat::CLI| => ['department', 'list', '--query "name=Test"']);

    ok !$result->error, 'list with query: threw no exception';

    $output = $result->stdout;
    ok $output , 'list departments with query: got an output';

    $count = count_department($output);

    ok $count == 1, 'count for list departments with query';
};

subtest 'export' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'export']);

    ok !$result->error, "threw no exception";
    like $result->output, qr/_id:/, "export output";

    $result = test_app(qq|LibreCat::CLI| => ['department', 'export', '--sort name']);
    ok $result->error, "threw an exception";
    like $result->stderr, qr/warning: sort only active/, "throws warning for sort without query parameter";

    $result = test_app(qq|LibreCat::CLI| => ['department', 'export', '--sort name', '--query "name: Test"']);
    ok !$result->error, "threw no exception";
    like $result->output, qr/name: Test faculty/, "export by query";
};

subtest 'delete' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['department', 'delete', '999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted 999000999/, 'deleted 999000999';

    $result
        = test_app(qq|LibreCat::CLI| => ['department', 'get', '999000999']);

    ok $result->error, 'ok no exception';

    $output = $result->stdout;
    ok length($output) == 0, 'got no result';

    $result = test_app(
        qq|LibreCat::CLI| => ['department', 'delete', '12345678909876543']);

    ok $result->error, 'throw exception: delete non-existent ID';
    like $result->stderr, qr/^ERROR: delete.*?failed$/, 'error message: delete non-existent ID';
};

subtest 'tree' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'tree', 't/records/valid-department-tree.yml']);

    ok !$result->error, "threw no exception";

    like $result->output, qr/deleting previous departments/, "clean tree before adding";

    $result = test_app(qq|LibreCat::CLI| => ['department', 'tree', ]);

    ok !$result->error, "threw no exception";
    like $result->output, qr/tree:/, "tree ouput";
};

done_testing;

sub count_department {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
