package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
use Catmandu::Util qw(:array);
use App::Catalog::Admin;
use App::Catalog::Helper;
use App::Catalog::Import;
use App::Catalog::Interface;
use App::Catalog::Person;
use App::Catalog::Publication;
use App::Catalog::Search;
use App::Catalog::Test;

use Authentication::Authenticate;

Catmandu->load;

hook 'before' => sub {
    if ( !session('user') && request->path_info !~ m{login} ) {
        var requested_path => request->path_info;
        request->path_info('/myPUB/login');
    }
};

get '/' => sub {
    my $params = params;

    forward '/myPUB/search', $params;
};

get '/login' => sub {
    my $data = { path => vars->{requested_path} };
    $data->{error_message} = params->{error_message} ||= '';
    template 'login', $data;
};

post '/login' => sub {
    my $bag  = Catmandu->store('authority')->bag;
    my $user = h->getAccount( params->{user} );

    if ($user) {

        #username is in PUB
        if ( verifyUser( params->{user}, params->{pass} ) ) {
            session role => $user->[0]->{isSuperAdminAccount}
                ? "superAdmin"
                : "user";
            session user         => $user->[0]->{login};
            session personNumber => $user->[0]->{personNumber};
            redirect params->{path} || '/myPUB/search';
        }
        else {
            forward '/myPUB/login',
                { error_message => "Wrong username or password!" },
                { method        => 'GET' };
        }
    }
    else {
        forward '/myPUB/login',
            { error_message =>
                "No such user in PUB. Please register first!" },
            { method => 'GET' };
    }
};

get '/logout' => sub {
    session->destroy;
    redirect '/myPUB/login';
};

1;
