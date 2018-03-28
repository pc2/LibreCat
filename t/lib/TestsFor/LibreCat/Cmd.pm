package TestsFor::LibreCat::Cmd;

use Test::Class::Moose;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Catmandu;
use LibreCat::CLI;
use App::Cmd::Tester;
use Data::Dumper;

sub _get_name {
    my $test = shift;

    $test->{test_instance_name} =~ /TestsFor::LibreCat::Cmd::(\w{2,})/;
    $1 // undef;
}

sub _get_test_record_id {
    my $name = shift;
    return Catmandu->importer('YAML', file => "t/records/valid-$name.yml")->first->{_id};
}

sub _count {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}

sub test_startup {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    Catmandu->store('main')->bag($name)->delete_all;
    Catmandu->store('search')->bag($name)->delete_all;
    Catmandu->store('main')->bag($name . "_version")->delete_all;
}

sub test_load {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $pkg = "LibreCat::Cmd::$name";
    use_ok $pkg;
    require_ok $pkg;
}

sub test_base_cmd {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $result = test_app(qq|LibreCat::CLI| => [$name]);
    ok $result->error, 'missing command: threw an exception';

    $result = test_app(qq|LibreCat::CLI| => [$name, 'nonsense-command']);
    ok $result->error, 'non-valid command: threw an exception';
    like $result->error, qr/Error.*?should be one of/, 'print valid commands';
};

sub test_help {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    for my $h (qw(-h --help -?)) {
        my $result = test_app(qq|LibreCat::CLI| => [$name, $h]);
        # ok !$result->error, 'help cmd: throw no exception';
        like $result->stdout, qr/print this usage screen/, 'print help';
    }
};


sub test_empty_list {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $result = test_app(qq|LibreCat::CLI| => [$name, "list"]);
    ok !$result->error, "list $name : threw no exception";
    my $output = $result->stdout;
    ok $output , "list $name: got an output";
    my $count = _count($output);
    ok $count == 0, "count for empty list $name";
}

sub test_validate {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $result = test_app(qq|LibreCat::CLI| =>
            [$name, "valid", "t/records/invalid-$name.yml"]);

    ok $result->error, "throw exception: non-valid $name";
    like $result->output, qr/^ERROR/, "error output for non-valid $name";

    $result = test_app(qq|LibreCat::CLI| =>
            [$name, "valid", "t/records/valid-$name.yml"]);
    ok !$result->error, "no exception: valid $name";
    unlike $result->output, qr/^ERROR/, "no error message for valid $name";
}

sub test_add_invalid {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $result = test_app(qq|LibreCat::CLI| =>
            [$name, "add"]);
    ok $result->error, "missing file in add";
    like $result->error, qr/usage.*add/, "error message: need file";

    $result = test_app(qq|LibreCat::CLI| =>
            [$name, "add", "t/records/blabla-$name.yml"]);
    ok $result->error, "nonexistent file in add";
    like $result->error, qr/usage.*add/, "error message need file";

    $result = test_app(qq|LibreCat::CLI| =>
            [$name, "add", "t/records/invalid-$name.yml"]);
    ok $result->error, "throw exception: add invalid $name";
}

sub test_add_valid {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $result = test_app(qq|LibreCat::CLI| =>
            [$name, "add", "t/records/valid-$name.yml"]);
    ok !$result->error, "add valid $name: threw no exception";
    my $output = $result->stdout;
    ok $output , "got an output";
    like $output , qr/^added \w+/, "message: added $name";

    $output =~ /added (\w+)/;
    my $id = $1;

    my $stored_record
        = Catmandu->store('main')->bag($name)->get($id);
    is $stored_record->{_id}, $id, 'stored record id';

    my $indexed_record
        = Catmandu->store('search')->bag($name)->get($id);
    is $indexed_record->{_id}, $id, 'indexed record id';
}

sub test_get {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $id = _get_test_record_id($name);

    my $result
        = test_app(qq|LibreCat::CLI| => [$name, "get", $id]);
    ok !$result->error, 'throw no exception';
    my $output = $result->stdout;
    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);
    my $record = $importer->first;

    is $record->{_id},  $id,      "got really $name record with ID $id";

    $result = test_app(qq|LibreCat::CLI| => [$name, "get", "t/records/$name-ids.txt"]);
    ok !$result->error, "threw no exception";
    $output = $result->stdout;
    ok $output , "got an output";
}

sub test_list {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $result = test_app(qq|LibreCat::CLI| => [$name, "list"]);
    ok !$result->error, "throw no exception";
    my $output = $result->stdout;
    ok $output , "got an output";
    my $count = _count($output);
    ok $count == 1, "count for list $name";


    # $result = test_app(qq|LibreCat::CLI| => [$name, "list", "--query 'test'"]);
    # ok !$result->error, 'list with query: threw no exception';
    # $output = $result->stdout;
    # ok $output , "list $name with query: got an output";
    # $count = _count($output);
    # ok $count == 1, "count for list $name with query";
};

sub test_export {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $result = test_app(qq|LibreCat::CLI| => [$name, "export"]);

    ok !$result->error, "throw no exception";
    like $result->output, qr/_id:/, "export output looks like YAML";

    $result = test_app(qq|LibreCat::CLI| => [$name, "export", "--sort name,,1"]);
    ok $result->error, "throw exception";
    like $result->stderr, qr/warning: sort only active/, "throws warning for sort without query parameter";

    $result = test_app(qq|LibreCat::CLI| => [$name, "export", "--sort name,,1", "--query 'name: Test'"]);
    ok !$result->error, "throw no exception";
    like $result->output, qr/name: Test faculty/, "export by query";
}

sub test_delete {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    my $id = _get_test_record_id($name);

    my $result = test_app(
        qq|LibreCat::CLI| => [$name, "delete", $id]);
    ok !$result->error, "throw no exception";
    my $output = $result->stdout;
    ok $output , "got an output";
    like $output , qr/^deleted \w+/, "deleted $name with ID $id";

    $result
        = test_app(qq|LibreCat::CLI| => [$name, "get", $id]);
    ok $result->error, "ok no exception";
    $output = $result->stdout;
    ok length($output) == 0, "no result deleted ID";

    # TODO: test should work, change lib sources
    # $result = test_app(
    #     qq|LibreCat::CLI| => [$name, "delete", "nonsense-id-12345"]);
    # ok $result->error, "throw exception: delete non-existent ID";
    # like $result->stderr, qr/^ERROR: delete.*?failed$/, "error message: delete non-existent ID";
}

sub test_shutdown {
    my $test = shift;
    my $name = _get_name($test);

    $test->test_skip("No subclass") unless $name;

    Catmandu->store('main')->bag($name)->delete_all;
    Catmandu->store('search')->bag($name)->delete_all;
    Catmandu->store('main')->bag($name . "_version")->delete_all;
}

1;
